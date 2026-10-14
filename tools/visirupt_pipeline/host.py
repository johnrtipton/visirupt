"""Private native host generation and normal signing; no device side effects."""
from datetime import datetime,timezone
import json
from pathlib import Path
import plistlib
import re
import shutil
from .core import PipelineError,sha256
from .macho import parse_macho
from .runner import run_tool
from .workspace import checked_workspace,atomic_json,private_directory
from .stages import run_stage,stage_fingerprint
from .verify import verify,framework_paths,verify_game,verify_provider
from .builders import copy_sources,all_framework_files,verify_native_framework,CURL_EXPORTS,SECURITY_EXPORTS

BUNDLE='local.games.cyberpunk.assetreceiver'
MEMORY_KEYS=('com.apple.developer.kernel.extended-virtual-addressing','com.apple.developer.kernel.increased-memory-limit')

def validate_signing_team(team):
    if not isinstance(team,str) or not re.fullmatch('[A-Z0-9]{10}',team):raise PipelineError('UNSUPPORTED_INPUT','explicit signing team required')
    return team

def read_tool_plist(path):
    data=path.read_bytes();start=data.find(b'<?xml');end=data.find(b'</plist>',start)
    if start<0 or end<0:raise PipelineError('INVALID_BINARY','tool plist output')
    try:return plistlib.loads(data[start:end+8])
    except (ValueError,plistlib.InvalidFileException):raise PipelineError('INVALID_BINARY','malformed signing metadata') from None

def inspect_signed_app(app:Path,recipe,runner=run_tool):
    checked_workspace(app,[])
    if not app.is_dir():raise PipelineError('INVALID_BINARY','missing app')
    info=plistlib.loads((app/'Info.plist').read_bytes())
    if info.get('CFBundleIdentifier')!=BUNDLE or info.get('CFBundleSupportedPlatforms')!=['XROS']:
        raise PipelineError('INVALID_BINARY','host package identity')
    executable=info.get('CFBundleExecutable')
    if not isinstance(executable,str) or Path(executable).name!=executable:raise PipelineError('INVALID_BINARY','host executable name')
    binary=app/executable;checked_workspace(binary,[]);image=parse_macho(binary.read_bytes())
    if image['kind']!=2 or tuple(image['platform'] or ())!=(11,0x1a0000,0x1b0000):raise PipelineError('INVALID_BINARY','host target')
    logs=app.parent/'SigningDiagnostics';private_directory(logs)
    runner(['codesign','--verify','--deep','--strict','--verbose=2',str(app)],app.parent,logs/'verify.log',120)
    runner(['codesign','-d','--entitlements',':-',str(app)],app.parent,logs/'entitlements.log',60)
    ent=read_tool_plist(logs/'entitlements.log')
    appid=ent.get('application-identifier') or ent.get('com.apple.application-identifier')
    team=ent.get('com.apple.developer.team-identifier');validate_signing_team(team)
    if appid!=team+'.'+BUNDLE or any(ent.get(key) is not True for key in MEMORY_KEYS):raise PipelineError('INVALID_BINARY','host entitlements')
    profile=app/'embedded.mobileprovision';checked_workspace(profile,[])
    if not profile.is_file():raise PipelineError('INVALID_BINARY','missing provisioning profile')
    runner(['security','cms','-D','-i',str(profile)],app.parent,logs/'profile.log',60)
    provision=read_tool_plist(logs/'profile.log');allowed=provision.get('Entitlements',{})
    permitted=allowed.get('application-identifier') or allowed.get('com.apple.application-identifier')
    if permitted not in (appid,team+'.*') or team not in provision.get('TeamIdentifier',[]) or allowed.get('com.apple.developer.team-identifier')!=team or any(allowed.get(key) is not True for key in MEMORY_KEYS):
        raise PipelineError('INVALID_BINARY','profile does not grant requested identity/capabilities')
    expires=provision.get('ExpirationDate')
    if not isinstance(expires,datetime) or expires.replace(tzinfo=timezone.utc)<=datetime.now(timezone.utc):raise PipelineError('INVALID_BINARY','expired or unknown profile')
    return {'bundle_identifier':BUNDLE,'application_identifier':appid,'team_identifier':team,
            'executable_sha256':sha256(binary),'signature_verified':True,'provisioning_verified':True}

def private_host_project(source_root:Path,root:Path,frameworks,runner=run_tool):
    tree=root/'engine';copy_sources(source_root,tree)
    relative='scratch/cyberpunk-staged-startup';source=source_root/relative
    for path in source.rglob('*'):
        if path.is_symlink():raise PipelineError('WORKSPACE_OVERLAP','host source symlink')
    shutil.copytree(source,tree/relative,ignore=shutil.ignore_patterns('*.xcodeproj','DerivedData','HostDerivedData','Frameworks','tests'))
    for name,path in frameworks.items():
        destination=tree/relative/'Frameworks'/(name+'.framework')
        shutil.copytree(path.parent,destination)
        # Xcode's embed processing requires a consistent signed LINKEDIT layout.
        # This local ad-hoc signature is replaced by the user's normal app build.
        runner(['codesign','--force','--sign','-','--identifier','local.research.'+name.lower(),str(destination)],tree/relative,root/('embed-'+name+'.log'),120)
    return tree/relative

def verify_embedded(app,workspace,recipe):
    from .preparation import snapshot_manifest
    manifest,snapshots=snapshot_manifest(workspace)
    paths=framework_paths(workspace)
    for name in paths:
        path=app/'Frameworks'/(name+'.framework')/name;checked_workspace(path,[])
        data=path.read_bytes()
        if name=='CyberpunkModule':verify_game((snapshots/manifest[name]['snapshot']).read_bytes(),data,recipe)
        elif name in manifest:verify_provider(name,(snapshots/manifest[name]['snapshot']).read_bytes(),data,recipe)
        else:verify_native_framework(path,name,CURL_EXPORTS if name=='Curl' else SECURITY_EXPORTS if name=='NativeSecurity' else ())
    memory=app/'Frameworks/MemoryTrace.framework/MemoryTrace'
    verify_native_framework(memory,'MemoryTrace')
    image=parse_macho(memory.read_bytes())
    if not any(dep['path']=='/usr/lib/libSystem.B.dylib' and dep['command']==0x8000001f for dep in image['dependencies']):raise PipelineError('INVALID_BINARY','missing libSystem reexport')

def build_host(source_root:Path,workspace:Path,recipe,team:str):
    validate_signing_team(team);checked_workspace(workspace,[source_root])
    verify(workspace,recipe);frameworks=framework_paths(workspace)
    fingerprint=stage_fingerprint({'recipe':recipe,'team':team,'providers':{name:sha256(path) for name,path in frameworks.items()},'sources':[(str(p.relative_to(source_root)),sha256(p)) for p in sorted((source_root/'scratch/cyberpunk-staged-startup').rglob('*')) if p.is_file() and p.suffix in ('.m','.c','.h','.swift','.yml','.entitlements')]})
    def build(root):
        cwd=private_host_project(source_root,root,frameworks)
        run_tool(['xcodegen','generate','--spec','project.yml'],cwd,root/'generate.log',120)
        derived=root/'DerivedData'
        run_tool(['xcodebuild','-project','CyberpunkStartupFileProbe.xcodeproj','-scheme','CyberpunkStartupFileProbe','-configuration','Debug','-sdk','xros','-destination','generic/platform=visionOS','-derivedDataPath',str(derived),'DEVELOPMENT_TEAM='+team,'CODE_SIGN_STYLE=Automatic','-allowProvisioningUpdates','build'],cwd,root/'build.log',1200)
        app=derived/'Build/Products/Debug-xros/CyberpunkStartupFileProbe.app'
        identity=inspect_signed_app(app,recipe)
        if identity['team_identifier']!=team:raise PipelineError('INVALID_BINARY','unexpected signing team')
        verify_embedded(app,workspace,recipe)
        destination=root/'Host.app';shutil.copytree(app,destination)
        identity['app_path']=str(destination.relative_to(workspace));atomic_json(root/'identity.json',identity)
        files=all_framework_files(destination);files.append(root/'identity.json')
        return files
    receipt=run_stage(workspace,'host',fingerprint,build)
    # Never treat a cached expired signature/profile as a fresh build success.
    identity_file=next(workspace/a['path'] for a in receipt['outputs'] if Path(a['path']).name=='identity.json')
    identity=json.loads(identity_file.read_text());app=workspace/identity['app_path']
    inspect_signed_app(app,recipe);verify_embedded(app,workspace,recipe)
    return receipt
