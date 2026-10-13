"""Exact, copy-only executable conversion with independently verified postconditions."""
import hashlib
import struct
from pathlib import Path
from .core import PipelineError,sha256
from .macho import parse_macho,unpack,LOADS
from .providers import remap_imports,strip_signature,repack,library_command,package_framework
from .workspace import checked_workspace

COCOA='/System/Library/Frameworks/Cocoa.framework/Versions/A/Cocoa'

def convert_game(data:bytes,recipe):
    if hashlib.sha256(data).hexdigest()!=recipe['inputs']['CyberpunkModule']['sha256']:raise PipelineError('UNSUPPORTED_INPUT','game identity')
    image=parse_macho(data)
    if image['kind']!=2 or not image['platform'] or image['platform'][0]!=1 or image['identity']:
        raise PipelineError('INVALID_BINARY','expected original executable')
    if len(image['sections'])!=recipe['game']['sections'] or len(image['dependencies'])!=24 or image['dependencies'][3]['path']!=COCOA:
        raise PipelineError('INVALID_BINARY','unexpected game metadata')
    after=remap_imports(data,image,{4},set(),0)
    after=strip_signature(after,image)
    for address,expected,replacement in recipe['game']['capacity_changes']:
        matching=[s for s in image['sections'] if s['name']=='__text' and s['address']<=address and address+4<=s['address']+s['size']]
        if len(matching)!=1:raise PipelineError('INVALID_BINARY','capacity address')
        section=matching[0];offset=section['offset']+address-section['address']
        if unpack('<I',data,offset)[0]!=expected:raise PipelineError('INVALID_BINARY','capacity instruction mismatch')
        struct.pack_into('<I',after,offset,replacement)
    commands=[];ordinal=0;pagezeros=0
    for command in image['commands']:
        typ=command['cmd'];block=bytearray(command['raw'])
        if typ in (14,0x80000028,0x1d):continue
        if typ in LOADS:
            ordinal+=1
            if ordinal==4:continue
            dep=image['dependencies'][ordinal-1]
            block=library_command(typ,recipe['routes'].get(dep['path'],dep['path']),dep['current'],dep['compatibility'],unpack('<I',block,12)[0])
        elif typ==25 and block[8:24].rstrip(b'\0')==b'__PAGEZERO':
            if unpack('<Q',block,24)[0]!=0 or unpack('<Q',block,48)[0]!=0:raise PipelineError('INVALID_BINARY','PAGEZERO metadata')
            struct.pack_into('<Q',block,32,0);pagezeros+=1
        elif typ==0x32:struct.pack_into('<III',block,8,11,0x1a0000,0x1b0000)
        commands.append(bytes(block))
    if pagezeros!=1:raise PipelineError('INVALID_BINARY','PAGEZERO count')
    commands.append(library_command(13,'@rpath/CyberpunkModule.framework/CyberpunkModule'))
    return repack(after,image,commands,kind=6,flags=image['flags']&~0x200000)

def prepare_game(source:Path,output:Path,recipe):
    checked_workspace(output,[source])
    if source.is_symlink():raise PipelineError('UNSUPPORTED_INPUT','symlink input')
    data=source.read_bytes();after=convert_game(data,recipe)
    from .verify import verify_game
    gates=verify_game(data,after,recipe)
    if sha256(source)!=recipe['inputs']['CyberpunkModule']['sha256']:raise PipelineError('SOURCE_CHANGED')
    package_framework('CyberpunkModule',output,after)
    return {'path':str(output),'bytes':len(after),'sha256':hashlib.sha256(after).hexdigest(),'gates':gates}
