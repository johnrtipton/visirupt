"""Copy-only native provider preparation for the exact reviewed game identity."""
import hashlib
import plistlib
import struct
from pathlib import Path
from .core import PipelineError,sha256
from .macho import parse_macho,checked_slice,unpack,LOADS
from .bindings import inventory_imports,inventory_exports,decode_leb
from .workspace import checked_workspace,private_directory

APP_SYMBOLS={'_NSApp','_NSApplicationDidBecomeActiveNotification','_NSApplicationWillResignActiveNotification','_syslog$DARWIN_EXTSN','_OBJC_CLASS_$_GKDialogController'}
SECURITY_SYMBOLS={'_SecItemImport','_SecItemExport','_SecIdentityCreateWithCertificate','_SecCertificateCopyLongDescription'}
NATIVE_NAMES={'CoreAudio','AudioToolbox','GameKit','Foundation','CoreFoundation','Security','SystemConfiguration'}

def native_path(path):
    for name in NATIVE_NAMES:
        for version in ('A','C'):
            if path==f'/System/Library/Frameworks/{name}.framework/Versions/{version}/{name}':
                return f'/System/Library/Frameworks/{name}.framework/{name}'
    return path

def provider_policy(name,image):
    if name=='Bink':
        removed={1,4};selected=set();adapter=None
        expected={1:'/System/Library/Frameworks/AudioUnit.framework/Versions/A/AudioUnit',4:'/System/Library/Frameworks/Carbon.framework/Versions/A/Carbon'}
    elif name=='AppStoreServices':
        removed={1};selected=APP_SYMBOLS;adapter='@rpath/HostAdapters.framework/HostAdapters'
        expected={1:'/System/Library/Frameworks/AppKit.framework/Versions/C/AppKit'}
    elif name=='GalaxyServices':
        removed={1};selected=SECURITY_SYMBOLS;adapter='@rpath/NativeSecurity.framework/NativeSecurity'
        expected={1:'/System/Library/Frameworks/Cocoa.framework/Versions/A/Cocoa'}
    else:raise PipelineError('UNSUPPORTED_INPUT','provider name')
    if len(image['dependencies'])!={'Bink':5,'AppStoreServices':7,'GalaxyServices':6}[name]:raise PipelineError('INVALID_BINARY','dependency count')
    for ordinal,path in expected.items():
        if image['dependencies'][ordinal-1]['path']!=path:raise PipelineError('INVALID_BINARY','umbrella identity')
    return removed,selected,adapter

def library_command(cmd,path,current=0x10000,compat=0x10000,timestamp=0):
    text=path.encode()+b'\0';size=(24+len(text)+7)&~7
    return struct.pack('<6I',cmd,size,24,timestamp,current,compat)+text+b'\0'*(size-24-len(text))

def remap_imports(data,image,removed,selected,new_ordinal):
    after=bytearray(data);records=inventory_imports(data,image)
    changed={}
    for row in records:
        ordinal=row['ordinal']
        if row['symbol'] in selected:new=new_ordinal;changed.setdefault(row['source'],set()).add(row['symbol'])
        elif ordinal in removed:raise PipelineError('INVALID_BINARY','removed provider has live imports')
        elif 1<=ordinal<=len(image['dependencies']):new=ordinal-sum(r<ordinal for r in removed)
        else:new=ordinal
        if new==ordinal:continue
        if row['source']=='chained':
            width=row['width'];loc=row['offset'];fmt='<Q' if width==16 else '<I';bits=unpack(fmt,data,loc)[0];mask=(1<<width)-1
            struct.pack_into(fmt,after,loc,(bits&~mask)|(new&mask))
        elif row['source']=='nlist':
            desc=unpack('<H',data,row['offset']+6)[0]
            struct.pack_into('<H',after,row['offset']+6,(desc&255)|(new<<8))
        else:
            loc=row['ordinal_offset']
            if loc is None:raise PipelineError('INVALID_BINARY','implicit ordinal remap')
            opcode=data[loc]&240
            if opcode==16 and 0<=new<16:after[loc]=16|new
            elif opcode==32:
                _,end=decode_leb(data,loc+1);encoded=[];value=new
                while True:
                    chunk=value&127;value>>=7;encoded.append(chunk|(128 if value else 0))
                    if not value:break
                if len(encoded)!=end-loc-1:raise PipelineError('INVALID_BINARY','ordinal encoding growth')
                after[loc+1:end]=bytes(encoded)
            else:raise PipelineError('INVALID_BINARY','ordinal opcode')
    if selected and (changed.get('chained')!=selected or changed.get('nlist')!=selected):
        raise PipelineError('INVALID_BINARY','selected symbol inventory')
    for export in inventory_exports(data,image):
        if 'ordinal' in export and export['ordinal'] in removed:raise PipelineError('INVALID_BINARY','removed reexport')
        # None of these reviewed libraries has ordinal-bearing export reexports.
        if 'ordinal' in export:raise PipelineError('INVALID_BINARY','unreviewed export reexport')
    return after

def strip_signature(data,image):
    result=bytearray(data)
    if image['signature']:
        offset,size=image['signature']
        if offset+size!=len(data):raise PipelineError('INVALID_BINARY','signature is not final')
        result=result[:offset]
    return result

def repack(data,image,commands,kind=None,flags=None):
    result=bytearray(data);header_end=image['header_end'];first=min((s['offset'] for s in image['sections']),default=header_end)
    if any(checked_slice(data,header_end,first-header_end)):raise PipelineError('INVALID_BINARY','header padding')
    payload=b''.join(commands)
    if 32+len(payload)>first:raise PipelineError('INVALID_BINARY','insufficient header padding')
    result[32:first]=payload+b'\0'*(first-32-len(payload))
    struct.pack_into('<II',result,16,len(commands),len(payload))
    if kind is not None:struct.pack_into('<I',result,12,kind)
    if flags is not None:struct.pack_into('<I',result,24,flags)
    # Removing/replacing signatures or aligning strings changes LINKEDIT's file extent.
    cursor=32
    for block in commands:
        if unpack('<I',block)[0]==25 and block[8:24].rstrip(b'\0')==b'__LINKEDIT':
            off=unpack('<Q',block,40)[0]
            if off>len(result):raise PipelineError('INVALID_BINARY','LINKEDIT offset')
            size=len(result)-off
            struct.pack_into('<Q',result,cursor+48,size)
            struct.pack_into('<Q',result,cursor+32,(size+16383)&~16383)
        cursor+=len(block)
    return bytes(result)

def convert_provider(name,data,recipe):
    if hashlib.sha256(data).hexdigest()!=recipe['inputs'][name]['sha256']:raise PipelineError('UNSUPPORTED_INPUT','provider identity')
    image=parse_macho(data)
    if image['kind']!=6 or not image['platform'] or image['platform'][0]!=1:raise PipelineError('INVALID_BINARY','expected original Mac library')
    removed,selected,adapter=provider_policy(name,image)
    new_ordinal=len(image['dependencies'])-len(removed)+1 if adapter else 0
    after=remap_imports(data,image,removed,selected,new_ordinal)
    after=strip_signature(after,image)
    if name=='Bink':
        if not image['symtab']:raise PipelineError('INVALID_BINARY','Bink symtab')
        so,count,old,size=image['symtab'];pool=checked_slice(after,old,size);aligned=(old+7)&~7
        if any(after[old+size:]):raise PipelineError('INVALID_BINARY','nonzero tail after Bink strings')
        after=after[:old]+b'\0'*(aligned-old)+pool
    commands=[];ordinal=0;has_id=False
    for cmd in image['commands']:
        typ=cmd['cmd'];block=bytearray(cmd['raw'])
        if typ==0x1d:continue
        if typ in LOADS:
            ordinal+=1
            if ordinal in removed:continue
            dep=image['dependencies'][ordinal-1]
            block=library_command(typ,native_path(dep['path']),dep['current'],dep['compatibility'],unpack('<I',block,12)[0])
        elif typ==13:
            has_id=True;dep=image['identity'];block=library_command(13,f'@rpath/{name}.framework/{name}',dep['current'],dep['compatibility'],unpack('<I',block,12)[0])
        elif typ==0x32:struct.pack_into('<III',block,8,11,0x1a0000,0x1b0000)
        elif typ==2 and name=='Bink':struct.pack_into('<I',block,16,aligned)
        commands.append(bytes(block))
    if not has_id:raise PipelineError('INVALID_BINARY','missing library identity')
    if adapter:commands.append(library_command(12,adapter))
    return repack(after,image,commands)

def package_framework(name,output,data):
    checked_workspace(output,[])
    if output.exists():raise PipelineError('WORKSPACE_OVERLAP','output already exists')
    private_directory(output.parent)
    info={'CFBundleExecutable':name,'CFBundleIdentifier':'local.research.'+name.lower(),'CFBundleName':name,
          'CFBundlePackageType':'FMWK','CFBundleShortVersionString':'1.0','CFBundleVersion':'1',
          'CFBundleSupportedPlatforms':['XROS'],'MinimumOSVersion':'26.0'}
    with output.open('xb') as stream:stream.write(data)
    output.chmod(0o600)
    metadata=output.parent/'Info.plist';checked_workspace(metadata,[])
    with metadata.open('xb') as stream:plistlib.dump(info,stream)
    metadata.chmod(0o600)

def prepare_provider(name,source:Path,output:Path,recipe):
    checked_workspace(output,[source])
    if source.is_symlink():raise PipelineError('UNSUPPORTED_INPUT','symlink source')
    data=source.read_bytes();after=convert_provider(name,data,recipe)
    from .verify import verify_provider
    gates=verify_provider(name,data,after,recipe)
    if sha256(source)!=recipe['inputs'][name]['sha256']:raise PipelineError('SOURCE_CHANGED')
    package_framework(name,output,after)
    return {'path':str(output),'bytes':len(after),'sha256':hashlib.sha256(after).hexdigest(),'gates':gates}
