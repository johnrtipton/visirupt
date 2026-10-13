"""Exclusive receiver ownership, safe source mapping and native completion gates."""
import contextlib
import hashlib
import json
import os
from pathlib import Path
import tempfile
import uuid
from .core import PipelineError
from .workspace import atomic_json,private_directory,checked_workspace,workspace_lock
from .assets import normalized_asset_path

BUNDLE='local.games.cyberpunk.assetreceiver'

@contextlib.contextmanager
def device_writer_lock(device:str,bundle:str,workspace:Path):
    if not device or not bundle:raise PipelineError('UNSUPPORTED_INPUT','device/container required')
    key=hashlib.sha256((device+'\0'+bundle).encode()).hexdigest()
    root=Path(tempfile.gettempdir()).resolve()/('visirupt-device-locks-'+str(os.getuid()))
    try:
        with workspace_lock(workspace/'TransportClientMutex'), workspace_lock(root/key):yield
    except PipelineError as error:
        if error.code=='WORKSPACE_BUSY':raise PipelineError('DEVICE_BUSY') from None
        raise

def owner_id(workspace:Path) -> str:
    private_directory(workspace);path=workspace/'transfer-owner.json';checked_workspace(path,[])
    if path.exists():
        try:
            data=json.loads(path.read_text());owner=data['owner_id'];uuid.UUID(owner)
            return owner
        except (ValueError,KeyError,TypeError):raise PipelineError('INVALID_RECEIPT','writer identity') from None
    owner=str(uuid.uuid4());atomic_json(path,{'owner_id':owner});return owner

def source_file(source:Path,asset:dict,manifest:Path) -> Path:
    if asset.get('prepared_relative_path'):
        relative=asset['prepared_relative_path']
        if not isinstance(relative,str) or Path(relative).is_absolute() or '..' in Path(relative).parts:raise PipelineError('UNSUPPORTED_INPUT','prepared source path')
        root=manifest.parent;path=root/relative
    else:
        relative=asset.get('source_relative_path',asset['relative_path']);normalized_asset_path(relative)
        root=source;path=root/relative
    checked_workspace(path,[])
    if not path.is_file() or not path.resolve().is_relative_to(root.resolve()):raise PipelineError('UNSUPPORTED_INPUT','source escaped or missing')
    return path

def verify_native_completion(snapshot:dict,manifest:dict) -> dict:
    expected={asset['relative_path']:asset for asset in manifest['files']}
    native=snapshot.get('files')
    if not isinstance(native,dict) or set(native)!=set(expected):raise PipelineError('INCOMPLETE_TRANSFER','native file set')
    for path,asset in expected.items():
        item=native[path]
        if not isinstance(item,dict) or item.get('verified') is not True or type(item.get('offset')) is not int or item.get('offset')!=asset['bytes'] or item.get('source_sha256')!=asset['sha256']:
            raise PipelineError('INCOMPLETE_TRANSFER','native final hash/size gate')
    return {'state':'complete','files':len(expected),'verified_bytes':sum(asset['bytes'] for asset in expected.values())}
