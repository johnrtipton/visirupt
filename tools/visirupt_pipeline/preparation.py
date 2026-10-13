"""Local pipeline orchestration. Native device commands are absent."""
import json
import os
from pathlib import Path
import shutil
import urllib.request
import tempfile
from .core import PipelineError,identify_game,sha256
from .workspace import checked_workspace,atomic_json
from .stages import run_stage,read_receipt,validate_receipt,stage_fingerprint
from .builders import build_sources,source_fingerprint,all_framework_files
from .providers import prepare_provider
from .game import prepare_game


def stage_root(workspace,receipt):
    return workspace/Path(receipt['outputs'][0]['path']).parent

def snapshot_manifest(workspace):
    receipt=read_receipt(workspace,'inspect')
    if not receipt or not validate_receipt(workspace,receipt):raise PipelineError('INVALID_RECEIPT')
    path=next((workspace/a['path'] for a in receipt['outputs'] if Path(a['path']).name=='inputs.json'),None)
    if path is None:raise PipelineError('INVALID_RECEIPT')
    return json.loads(path.read_text()),path.parent

def prepare(source_root:Path,game_root:Path,workspace:Path,recipe,curl_archive:Path|None,download=False):
    from .cli import doctor
    checked_workspace(workspace,[source_root,game_root])
    state=doctor(recipe)
    if not state['supported_toolchain'] or not state['python_supported']:raise PipelineError('UNSUPPORTED_INPUT','toolchain does not match recipe')
    inputs=identify_game(game_root,recipe)
    if curl_archive is None and not download:raise PipelineError('UNSUPPORTED_INPUT','--curl-archive or --download-source required')
    if curl_archive is not None and (curl_archive.is_symlink() or sha256(curl_archive)!=recipe['curl']['archive_sha256']):raise PipelineError('UNSUPPORTED_INPUT','source archive identity')
    nearest=workspace
    while not nearest.exists():nearest=nearest.parent
    if shutil.disk_usage(nearest).free < 2*sum(v['bytes'] for v in inputs.values())+2*1024**3:raise PipelineError('UNSUPPORTED_INPUT','insufficient local build space')
    source_key=source_fingerprint(source_root,recipe)
    fingerprint=stage_fingerprint({'source':source_key,'recipe':recipe,'inputs':inputs,'sdk':state['sdk']})
    def inspect(root):
        manifest={};outputs=[]
        for name,spec in recipe['inputs'].items():
            src=game_root/'Contents'/spec['path'];dest=root/(name+'.original')
            with src.open('rb') as a,dest.open('xb') as b:shutil.copyfileobj(a,b,1024*1024)
            dest.chmod(0o600)
            if sha256(dest)!=spec['sha256'] or sha256(src)!=spec['sha256']:raise PipelineError('SOURCE_CHANGED')
            manifest[name]={'snapshot':dest.name,'sha256':spec['sha256']};outputs.append(dest)
        atomic_json(root/'inputs.json',manifest);outputs.append(root/'inputs.json')
        return outputs
    run_stage(workspace,'inspect',fingerprint,inspect)
    manifest,snapshots=snapshot_manifest(workspace)
    if curl_archive is None:curl_archive=download_archive(workspace,recipe)
    build_sources(source_root,workspace,recipe,curl_archive)
    def providers(root):
        files=[]
        for name in ('Bink','AppStoreServices','GalaxyServices'):
            output=root/'Frameworks'/(name+'.framework')/name
            prepare_provider(name,snapshots/manifest[name]['snapshot'],output,recipe)
            files.extend(all_framework_files(output.parent))
        return files
    run_stage(workspace,'providers',stage_fingerprint({'fingerprint':fingerprint,'stage':'providers'}),providers)
    def game(root):
        output=root/'Frameworks/CyberpunkModule.framework/CyberpunkModule'
        prepare_game(snapshots/manifest['CyberpunkModule']['snapshot'],output,recipe)
        return all_framework_files(output.parent)
    receipt=run_stage(workspace,'game',stage_fingerprint({'fingerprint':fingerprint,'stage':'game'}),game)
    identify_game(game_root,recipe)
    if source_key!=source_fingerprint(source_root,recipe):raise PipelineError('SOURCE_CHANGED')
    from .verify import verify
    verify(workspace,recipe)
    return receipt


def download_archive(workspace,recipe):
    """Fetch only the pinned official source into a uniquely owned private file."""
    from .workspace import private_directory
    private_directory(workspace)
    archive=workspace/'official-curl.tar.xz';checked_workspace(archive,[])
    if archive.exists():
        if sha256(archive)!=recipe['curl']['archive_sha256']:raise PipelineError('UNSUPPORTED_INPUT','existing archive identity')
        return archive
    fd,name=tempfile.mkstemp(prefix='official-curl-',suffix='.download',dir=workspace)
    temporary=Path(name)
    try:
        with os.fdopen(fd,'wb') as stream,urllib.request.urlopen(recipe['curl']['url'],timeout=60) as response:
            remaining=64*1024*1024
            while block:=response.read(min(1024*1024,remaining+1)):
                remaining-=len(block)
                if remaining<0:raise PipelineError('UNSUPPORTED_INPUT','source download size')
                stream.write(block)
            stream.flush();os.fsync(stream.fileno())
        if sha256(temporary)!=recipe['curl']['archive_sha256']:raise PipelineError('UNSUPPORTED_INPUT','download identity')
        checked_workspace(archive,[]);os.replace(temporary,archive)
        return archive
    finally:temporary.unlink(missing_ok=True)
