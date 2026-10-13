"""Independent semantic verification against immutable original inputs."""
import hashlib
from .core import PipelineError
from .macho import parse_macho,semantic_inventory,checked_slice

def require(condition,detail):
    if not condition:raise PipelineError('INVALID_BINARY',detail)

def verify_provider(name,original:bytes,prepared:bytes,recipe):
    # Independently express expected logical providers; never compare converter success flags.
    require(hashlib.sha256(original).hexdigest()==recipe['inputs'][name]['sha256'],'original identity')
    a=semantic_inventory(original);b=semantic_inventory(prepared)
    require(a['kind']==6 and a['platform'][0]==1,'original platform')
    require(b['kind']==6 and tuple(b['platform'])==(11,0x1a0000,0x1b0000),'device platform')
    require(b['identity']['path']==f'@rpath/{name}.framework/{name}','framework identity')
    require(len(a['sections'])==len(b['sections']),'section count')
    for before,after in zip(a['sections'],b['sections']):
        require(before==after,'section content or metadata changed')
    if name=='Bink':
        removed={1,4};selected=set();adapter=None
    elif name=='AppStoreServices':
        removed={1};selected={'_NSApp','_NSApplicationDidBecomeActiveNotification','_NSApplicationWillResignActiveNotification','_syslog$DARWIN_EXTSN','_OBJC_CLASS_$_GKDialogController'};adapter='@rpath/HostAdapters.framework/HostAdapters'
    elif name=='GalaxyServices':
        removed={1};selected={'_SecItemImport','_SecItemExport','_SecIdentityCreateWithCertificate','_SecCertificateCopyLongDescription'};adapter='@rpath/NativeSecurity.framework/NativeSecurity'
    else:raise PipelineError('UNSUPPORTED_INPUT','provider name')
    def normalize(path):
        import re
        allowed={'CoreAudio','AudioToolbox','GameKit','Foundation','CoreFoundation','Security','SystemConfiguration'}
        match=re.fullmatch(r'/System/Library/Frameworks/(\w+)\.framework/Versions/[AC]/\1',path)
        return f'/System/Library/Frameworks/{match[1]}.framework/{match[1]}' if match and match[1] in allowed else path
    expected=[dict(dep,path=normalize(dep['path'])) for i,dep in enumerate(a['dependencies'],1) if i not in removed]
    if adapter:expected.append({'path':adapter,'current':0x10000,'compatibility':0x10000,'command':12})
    require(len(expected)==len(b['dependencies']),'dependency count')
    for before,after in zip(expected,b['dependencies']):
        for key in ('path','current','compatibility','command'):require(before[key]==after[key],'dependency metadata')
    require(len(a['imports'])==len(b['imports']),'import count')
    for before,after in zip(a['imports'],b['imports']):
        expected_provider=adapter if before['symbol'] in selected else normalize(before['provider'])
        require(expected_provider==after['provider'],'logical import provider')
        for key in ('source','symbol','weak','addend'):
            require(before[key]==after[key],'import payload')
        if before['source']=='nlist':
            require(before['value']==after['value'] and before['descriptor']&255==after['descriptor']&255,'nlist payload')
        if before['source'].startswith('legacy_'):
            require(before['address']==after['address'] and before['type']==after['type'],'legacy bind address')
    require(a['exports']==b['exports'],'exports changed')
    old=parse_macho(original);new=parse_macho(prepared)
    if old['symtab']:
        old_pool=checked_slice(original,old['symtab'][2],old['symtab'][3]);new_pool=checked_slice(prepared,new['symtab'][2],new['symtab'][3])
        require(old_pool==new_pool,'symbol string pool changed')
    return {'sections_preserved':True,'logical_providers_verified':True,'device_target_verified':True,'exports_preserved':True}

def verify_game(original:bytes,prepared:bytes,recipe):
    import struct
    require(hashlib.sha256(original).hexdigest()==recipe['inputs']['CyberpunkModule']['sha256'],'original game identity')
    a=semantic_inventory(original);b=semantic_inventory(prepared);ia=parse_macho(original);ib=parse_macho(prepared)
    require(a['kind']==2 and a['platform'][0]==1,'original executable')
    require(b['kind']==6 and tuple(b['platform'])==(11,0x1a0000,0x1b0000),'device module')
    require(b['identity']['path']=='@rpath/CyberpunkModule.framework/CyberpunkModule','module identity')
    require(ib['flags']==ia['flags']&~0x200000,'module flags')
    require(not any(c['cmd'] in (14,0x80000028) for c in ib['commands']),'entrypoint load commands')
    require(len(a['sections'])==len(b['sections'])==recipe['game']['sections'],'game section count')
    initials=0
    for before,after in zip(a['sections'],b['sections']):
        require(all(before[k]==after[k] for k in ('segment','name','address','offset','size','flags')),'section metadata')
        expected=bytearray(checked_slice(original,before['offset'],before['size']))
        if before['name']=='__text':
            for address,old,new in recipe['game']['capacity_changes']:
                require(before['address']<=address and address+4<=before['address']+before['size'],'capacity bounds')
                at=address-before['address'];require(struct.unpack_from('<I',expected,at)[0]==old,'original capacity word')
                struct.pack_into('<I',expected,at,new)
        require(bytes(expected)==checked_slice(prepared,after['offset'],after['size']),'game section payload')
        if before['name']=='__init_offsets':
            require(before['size']%4==0,'initializer alignment');initials+=before['size']//4
    require(initials==recipe['game']['initializers'],'initializer count')
    require(len(ia['segments'])==len(ib['segments']),'segment count')
    for before,after in zip(ia['segments'],ib['segments']):
        require(before['name']==after['name'] and before['vm']==after['vm'],'segment identity')
        if before['name']=='__PAGEZERO':require(after['vmsize']==0 and after['filesize']==0,'PAGEZERO')
        elif before['name']!='__LINKEDIT':require(before==after,'segment metadata')
    expected=[dep for i,dep in enumerate(a['dependencies'],1) if i!=4]
    require(len(expected)==len(b['dependencies'])==23,'game dependency count')
    for before,after in zip(expected,b['dependencies']):
        require(after['path']==recipe['routes'].get(before['path'],before['path']),'game provider path')
        require(all(before[k]==after[k] for k in ('current','compatibility','command')),'client versions')
    require(len(a['imports'])==len(b['imports']),'game import count')
    for before,after in zip(a['imports'],b['imports']):
        require(after['provider']==recipe['routes'].get(before['provider'],before['provider']),'game logical provider')
        require(all(before[k]==after[k] for k in ('source','symbol','weak','addend')),'game import payload')
        if before['source']=='nlist':require(before['value']==after['value'] and before['descriptor']&255==after['descriptor']&255,'game nlist payload')
    require(a['exports']==b['exports'],'game exports')
    return {'initializers_preserved':True,'allowed_capacity_words_only':True,'logical_providers_verified':True,'device_target_verified':True}

def framework_paths(workspace):
    from .stages import read_receipt,validate_receipt
    paths={}
    for stage in ('adapters','security','curl','providers','game'):
        receipt=read_receipt(workspace,stage)
        if not receipt or not validate_receipt(workspace,receipt):raise PipelineError('INVALID_RECEIPT','prepared stage is not verified')
        for artifact in receipt['outputs']:
            path=workspace/artifact['path']
            if path.parent.suffix=='.framework' and path.name==path.parent.stem:
                if path.name in paths:raise PipelineError('INVALID_RECEIPT','duplicate framework')
                paths[path.name]=path
    if set(paths)!={'HostAdapters','DisplayBridge','IOKitBridge','MetalBridge','NativeSecurity','Curl','Bink','AppStoreServices','GalaxyServices','CyberpunkModule'}:
        raise PipelineError('INVALID_RECEIPT','missing prepared framework')
    return paths

def verify(workspace,recipe):
    import plistlib
    from .preparation import snapshot_manifest
    from .builders import verify_native_framework,CURL_EXPORTS,SECURITY_EXPORTS
    from .workspace import checked_workspace
    manifest,root=snapshot_manifest(workspace)
    if set(manifest)!=set(recipe['inputs']):raise PipelineError('INVALID_RECEIPT','original snapshot set')
    originals={}
    for name,spec in recipe['inputs'].items():
        entry=manifest[name]
        if entry.get('snapshot')!=name+'.original' or entry.get('sha256')!=spec['sha256']:raise PipelineError('INVALID_RECEIPT','snapshot identity')
        path=root/entry['snapshot'];checked_workspace(path,[]);data=path.read_bytes()
        if hashlib.sha256(data).hexdigest()!=spec['sha256']:raise PipelineError('INVALID_RECEIPT','original snapshot hash')
        originals[name]=data
    paths=framework_paths(workspace)
    for name,path in paths.items():
        metadata=plistlib.loads((path.parent/'Info.plist').read_bytes())
        require(metadata.get('CFBundleExecutable')==name and metadata.get('CFBundleSupportedPlatforms')==['XROS'] and metadata.get('MinimumOSVersion')=='26.0','framework package metadata')
        if name=='CyberpunkModule':verify_game(originals[name],path.read_bytes(),recipe)
        elif name in originals:verify_provider(name,originals[name],path.read_bytes(),recipe)
        else:verify_native_framework(path,name,CURL_EXPORTS if name=='Curl' else SECURITY_EXPORTS if name=='NativeSecurity' else ())
    return {'state':'complete','recipe':recipe['id'],'verified_frameworks':len(paths),'gameplay_confirmed':False}
