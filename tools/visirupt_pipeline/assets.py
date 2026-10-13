"""Private asset identity, case normalization and an exact local input override."""
import hashlib
import json
import os
from pathlib import Path
import re
import unicodedata
import xml.etree.ElementTree as ET
from .core import PipelineError
from .workspace import checked_workspace,atomic_json,private_directory

MAPPING='Data/r6/config/inputUserMappings.xml'

def normalized_asset_path(value:str) -> str:
    parts=value.split('/')
    if not parts or parts[0]!='Data' or any(not p or p in ('.','..') for p in parts) or '\\' in value or '\0' in value:
        raise PipelineError('UNSUPPORTED_INPUT','asset relative path')
    if len(parts)>2 and parts[1]=='archive' and parts[2]=='Mac':parts[2]='mac'
    return '/'.join(parts)

def stable_hash(path:Path) -> str:
    checked_workspace(path,[])
    with path.open('rb') as stream:
        before=os.fstat(stream.fileno());digest=hashlib.sha256()
        for block in iter(lambda:stream.read(1024*1024),b''):digest.update(block)
        after=os.fstat(stream.fileno())
    def identity(st):return st.st_dev,st.st_ino,st.st_size,st.st_mtime_ns,st.st_ctime_ns
    if identity(before)!=identity(after) or identity(after)!=identity(path.stat()):raise PipelineError('SOURCE_CHANGED')
    return digest.hexdigest()

def patch_arrow_mapping(original:bytes) -> bytes:
    if len(original)>2*1024*1024 or b'<!DOCTYPE' in original.upper() or b'<!ENTITY' in original.upper():raise PipelineError('UNSUPPORTED_INPUT','unsafe input mapping XML')
    try:tree=ET.fromstring(original)
    except ET.ParseError:raise PipelineError('UNSUPPORTED_INPUT','malformed input mapping') from None
    mappings=[node for node in tree.iter('mapping') if node.get('name')=='RightX_Axis']
    if len(mappings)!=1 or mappings[0].get('type')!='Axis':raise PipelineError('UNSUPPORTED_INPUT','input mapping structure')
    mapping=mappings[0];buttons=list(mapping.findall('button'))
    if len([b for b in buttons if b.get('id')=='IK_Pad_RightAxisX'])!=1:raise PipelineError('UNSUPPORTED_INPUT','original pad binding')
    arrows=[b for b in buttons if b.get('id') in ('IK_Left','IK_Right')]
    if arrows:
        if len(arrows)!=2 or {b.get('id'):b.get('val') for b in arrows}!={'IK_Left':'-1.0','IK_Right':'1.0'}:
            raise PipelineError('UNSUPPORTED_INPUT','unexpected existing arrow mapping')
        return original
    pattern=rb'<mapping\b[^>]*\bname\s*=\s*[\"\x27]RightX_Axis[\"\x27][^>]*>'
    matches=list(re.finditer(pattern,original))
    if len(matches)!=1:raise PipelineError('UNSUPPORTED_INPUT','ambiguous mapping text')
    match=matches[0];end=original.find(b'</mapping>',match.end())
    if end<0:raise PipelineError('UNSUPPORTED_INPUT','mapping close')
    insertion=b'\n        <button id="IK_Left" val="-1.0" />\n        <button id="IK_Right" val="1.0" />\n'
    result=original[:end]+insertion+original[end:]
    # Validate the surgical change; the rest of the user's original bytes are preserved.
    ET.fromstring(result)
    return result

def original_root(game_root:Path) -> Path:
    root=game_root/'Contents'
    if not (root/'Data').is_dir():raise PipelineError('UNSUPPORTED_INPUT','original Data tree missing')
    checked_workspace(root,[])
    return root

def build_asset_manifest(game_root:Path,output:Path,recipe) -> dict:
    checked_workspace(output,[game_root]);root=original_root(game_root)
    expected={};keys=set()
    for asset in recipe['assets']:
        relative=normalized_asset_path(asset['relative_path']);key=unicodedata.normalize('NFC',relative).casefold()
        if key in keys:raise PipelineError('UNSUPPORTED_INPUT','asset destination collision')
        keys.add(key);expected[relative]=asset
    found={}
    for path in sorted((root/'Data').rglob('*')):
        if path.is_symlink():raise PipelineError('UNSUPPORTED_INPUT','asset symlink')
        if path.is_file() and path.name!='.DS_Store':
            relative=str(path.relative_to(root));target=normalized_asset_path(relative);key=unicodedata.normalize('NFC',target).casefold()
            if key in found:raise PipelineError('UNSUPPORTED_INPUT','asset collision')
            found[key]=(path,target,relative)
    if set(found)!=keys:raise PipelineError('UNSUPPORTED_INPUT','asset file set does not match recipe')
    files=[];original_mapping=None;patched_mapping=None
    for _,(path,target,relative) in sorted(found.items(),key=lambda item:item[1][1]):
        spec=expected[target]
        if path.stat().st_size!=spec['bytes']:raise PipelineError('SOURCE_CHANGED','asset size')
        if stable_hash(path)!=spec['sha256']:raise PipelineError('SOURCE_CHANGED','asset hash')
        entry={'relative_path':target,'source_relative_path':relative,'bytes':spec['bytes'],'sha256':spec['sha256'],'original_bytes':spec['bytes'],'original_sha256':spec['sha256']}
        if target==MAPPING:
            original_mapping=path.read_bytes()
            if hashlib.sha256(original_mapping).hexdigest()!=spec['sha256']:raise PipelineError('SOURCE_CHANGED','mapping source')
            patched_mapping=patch_arrow_mapping(original_mapping)
            entry.update(bytes=len(patched_mapping),sha256=hashlib.sha256(patched_mapping).hexdigest(),prepared_relative_path='inputUserMappings.prepared.xml',intentional_modification='arrow camera turning')
        files.append(entry)
    if original_mapping is None:raise PipelineError('UNSUPPORTED_INPUT','required input mapping absent')
    # Only commit metadata/overrides after every original identity has passed.
    if output.exists() or (output.parent/'inputUserMappings.original.xml').exists() or (output.parent/'inputUserMappings.prepared.xml').exists():raise PipelineError('WORKSPACE_OVERLAP','asset metadata already exists')
    private_directory(output.parent)
    for name,data in (('inputUserMappings.original.xml',original_mapping),('inputUserMappings.prepared.xml',patched_mapping)):
        path=output.parent/name
        with path.open('xb') as stream:stream.write(data)
        path.chmod(0o600)
    result={'schema_version':1,'recipe':recipe['id'],'recipe_version':recipe['version'],'files':files}
    atomic_json(output,result)
    return result

def verify_asset_manifest(manifest:dict,root:Path) -> dict:
    root=original_root(root);seen=set()
    for asset in manifest['files']:
        target=normalized_asset_path(asset['relative_path']);key=unicodedata.normalize('NFC',target).casefold()
        if key in seen:raise PipelineError('UNSUPPORTED_INPUT','duplicate asset')
        seen.add(key);relative=asset['source_relative_path'];normalized_asset_path(relative)
        path=root/relative;checked_workspace(path,[])
        if not path.is_file() or not path.resolve().is_relative_to(root.resolve()):raise PipelineError('UNSUPPORTED_INPUT','asset source path')
        if path.stat().st_size!=asset['original_bytes'] or stable_hash(path)!=asset['original_sha256']:raise PipelineError('SOURCE_CHANGED','original asset identity')
    return {'originals_verified':True,'files':len(seen)}
