"""Source builders and safe pinned-archive extraction."""
import os
from pathlib import Path,PurePosixPath
import shutil
import tarfile
from .core import PipelineError,sha256
from .workspace import checked_workspace,private_directory
from .macho import semantic_inventory,parse_macho
from .providers import package_framework
from .runner import run_tool

CURL_EXPORTS={'_curl_'+name for name in ('easy_cleanup','easy_getinfo','easy_init','easy_perform','easy_setopt','easy_strerror','global_cleanup','global_init_mem','multi_add_handle','multi_cleanup','multi_info_read','multi_init','multi_perform','multi_remove_handle','slist_append','slist_free_all')}
SECURITY_EXPORTS={'_SecItemImport','_SecItemExport','_SecIdentityCreateWithCertificate','_SecCertificateCopyLongDescription'}

def extract_archive(archive:Path,destination:Path,expected_hash:str,root_name:str) -> Path:
    if archive.is_symlink() or sha256(archive)!=expected_hash:raise PipelineError('UNSUPPORTED_INPUT','archive identity')
    checked_workspace(destination,[archive])
    if destination.exists():raise PipelineError('WORKSPACE_OVERLAP','extract destination exists')
    with tarfile.open(archive,'r:*') as stream:
        members=stream.getmembers();seen=set();total=0
        if len(members)>50000:raise PipelineError('UNSUPPORTED_INPUT','archive entries')
        for member in members:
            path=PurePosixPath(member.name)
            if path.is_absolute() or '..' in path.parts or not path.parts or path.parts[0]!=root_name or not (member.isdir() or member.isreg()):
                raise PipelineError('UNSUPPORTED_INPUT','unsafe archive member')
            total+=member.size
            if total>512*1024*1024 or member.size<0:raise PipelineError('UNSUPPORTED_INPUT','archive size')
            if member.name in seen and not member.isdir():raise PipelineError('UNSUPPORTED_INPUT','duplicate archive member')
            seen.add(member.name)
        private_directory(destination)
        for member in members:
            path=destination.joinpath(*PurePosixPath(member.name).parts)
            checked_workspace(path,[])
            if member.isdir():private_directory(path)
            else:
                private_directory(path.parent)
                source=stream.extractfile(member)
                if source is None:raise PipelineError('UNSUPPORTED_INPUT','archive payload')
                with source,path.open('xb') as output:shutil.copyfileobj(source,output,1024*1024)
                path.chmod(0o700 if member.mode&0o111 else 0o600)
    return destination/root_name

def verify_native_framework(path:Path,name:str,required_exports=()) -> dict:
    if path.is_symlink() or not path.is_file():raise PipelineError('INVALID_BINARY','source-built framework')
    data=path.read_bytes();inv=semantic_inventory(data)
    if inv['kind']!=6 or tuple(inv['platform'] or ())!=(11,0x1a0000,0x1b0000) or not inv['identity'] or inv['identity']['path']!=f'@rpath/{name}.framework/{name}':
        raise PipelineError('INVALID_BINARY','source target or framework identity')
    exports={item['symbol'] for item in inv['exports']}
    if not set(required_exports)<=exports:raise PipelineError('INVALID_BINARY','missing source exports')
    for dep in inv['dependencies']:
        p=dep['path']
        if not (p.startswith('/System/Library/Frameworks/') or p.startswith('/usr/lib/') or p=='@rpath/HostAdapters.framework/HostAdapters') or '/opt/' in p:
            raise PipelineError('INVALID_BINARY','unexpected runtime dependency')
    if name in ('DisplayBridge','IOKitBridge','MetalBridge'):
        if not any(d['path']=='@rpath/HostAdapters.framework/HostAdapters' and d['command']==0x8000001f for d in inv['dependencies']):
            raise PipelineError('INVALID_BINARY','missing host reexport')
    return {'path':str(path),'bytes':len(data),'sha256':sha256(path),'gates':{'source_exports':True,'device_target':True}}

def all_framework_files(framework:Path):
    files=[]
    for path in sorted(framework.rglob('*')):
        if path.is_symlink():raise PipelineError('WORKSPACE_OVERLAP','generated framework symlink')
        if path.is_file():files.append(path)
    return files

def source_fingerprint(source_root:Path,recipe):
    from .stages import stage_fingerprint
    paths=[]
    for relative in ('cyberpunk-avp/compat','scratch/cyberpunk-consolidated-host','tools/visirupt_pipeline','recipes'):
        for path in sorted((source_root/relative).rglob('*')):
            if path.is_file() and path.suffix in ('.m','.h','.c','.swift','.yml','.py','.json'):
                if path.is_symlink():raise PipelineError('WORKSPACE_OVERLAP','source symlink')
                paths.append((str(path.relative_to(source_root)),sha256(path)))
    return stage_fingerprint({'recipe':recipe,'source_files':paths})

def copy_sources(source_root:Path,destination:Path):
    for relative in ('cyberpunk-avp/compat','scratch/cyberpunk-consolidated-host'):
        source=source_root/relative
        for path in source.rglob('*'):
            if path.is_symlink():raise PipelineError('WORKSPACE_OVERLAP','source symlink')
        shutil.copytree(source,destination/relative,ignore=shutil.ignore_patterns('*.xcodeproj','DerivedData','Frameworks','__pycache__'))

def build_adapters(source_root,root):
    copy_sources(source_root,root/'engine')
    cwd=root/'engine/scratch/cyberpunk-consolidated-host'
    run_tool(['xcodegen','generate','--spec','project.yml'],cwd,root/'generate.log',120)
    derived=root/'DerivedData'
    run_tool(['xcodebuild','-project','CyberpunkConsolidatedHost.xcodeproj','-scheme','HostAdapters','-configuration','Debug','-sdk','xros','-destination','generic/platform=visionOS','-derivedDataPath',str(derived),'CODE_SIGNING_ALLOWED=NO','build'],cwd,root/'build.log',900)
    files=[]
    for name in ('HostAdapters','DisplayBridge','IOKitBridge','MetalBridge'):
        source=derived/'Build/Products/Debug-xros'/(name+'.framework');destination=root/'Frameworks'/(name+'.framework')
        destination.parent.mkdir(mode=0o700,exist_ok=True)
        shutil.copytree(source,destination)
        verify_native_framework(destination/name,name)
        files.extend(all_framework_files(destination))
    return files

def build_security(source_root,root):
    src=source_root/'cyberpunk-avp/compat/Security';binary=root/'NativeSecurity'
    argv=['xcrun','--sdk','xros','clang','-target','arm64-apple-xros26.0','-dynamiclib','-fobjc-arc','-Wall','-Wextra','-Werror','-I'+str(src)]
    argv += [str(src/(n+'.m')) for n in ('CPClientIdentity','CPPublicKeyExport','CPCertificateLabel','CPDesktopSecurity')]
    argv += ['-framework','Foundation','-framework','Security']
    for own,public in (('CPDesktopItemImport','SecItemImport'),('CPDesktopItemExport','SecItemExport'),('CPDesktopIdentityCreateWithCertificate','SecIdentityCreateWithCertificate'),('CPDesktopCertificateCopyLongDescription','SecCertificateCopyLongDescription')):
        argv.append(f'-Wl,-alias,_{own},_{public}')
    argv += ['-install_name','@rpath/NativeSecurity.framework/NativeSecurity','-o',str(binary)]
    run_tool(argv,root,root/'build.log',180)
    framework=root/'Frameworks/NativeSecurity.framework'
    package_framework('NativeSecurity',framework/'NativeSecurity',binary.read_bytes())
    verify_native_framework(framework/'NativeSecurity','NativeSecurity',SECURITY_EXPORTS)
    return all_framework_files(framework)

def build_curl(root,recipe,archive):
    source=extract_archive(archive,root/'Source',recipe['curl']['archive_sha256'],'curl-'+recipe['curl']['version'])
    run_tool(['xcrun','--sdk','xros','--show-sdk-path'],root,root/'sdk.log',30)
    sdk=(root/'sdk.log').read_text().strip()
    run_tool(['xcrun','--sdk','xros','--find','clang'],root,root/'clang.log',30)
    clang=(root/'clang.log').read_text().strip()
    build=root/'Build'
    argv=['cmake','-S',str(source),'-B',str(build),'-G','Ninja','-DCMAKE_SYSTEM_NAME=Darwin','-DCMAKE_SYSTEM_VERSION=26.0','-DCMAKE_OSX_DEPLOYMENT_TARGET:STRING=','-DCMAKE_OSX_ARCHITECTURES=arm64','-DCMAKE_OSX_SYSROOT='+sdk,'-DCMAKE_C_COMPILER='+clang,'-DCMAKE_C_COMPILER_TARGET=arm64-apple-xros26.0','-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY','-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER','-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY','-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY','-DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY','-DCMAKE_BUILD_TYPE=Release']
    values={'BUILD_SHARED_LIBS':'ON','BUILD_CURL_EXE':'OFF','BUILD_TESTING':'OFF','CURL_USE_SECTRANSP':'ON','CURL_USE_OPENSSL':'OFF','CURL_USE_LIBPSL':'OFF','CURL_USE_LIBSSH2':'OFF','CURL_ZLIB':'OFF','CURL_BROTLI':'OFF','CURL_ZSTD':'OFF','USE_NGHTTP2':'OFF','USE_LIBIDN2':'OFF','CURL_DISABLE_LDAP':'ON','CURL_DISABLE_LDAPS':'ON','HAVE_PIPE2':'FALSE'}
    argv += ['-D'+key+'='+value for key,value in values.items()]
    run_tool(argv,root,root/'configure.log',300)
    run_tool(['cmake','--build',str(build),'--parallel','2'],root,root/'build.log',900)
    framework=root/'Frameworks/Curl.framework';package_framework('Curl',framework/'Curl',(build/'lib/libcurl.4.8.0.dylib').read_bytes())
    run_tool(['xcrun','install_name_tool','-id','@rpath/Curl.framework/Curl',str(framework/'Curl')],root,root/'identity.log',30)
    verify_native_framework(framework/'Curl','Curl',CURL_EXPORTS)
    return all_framework_files(framework)

def build_sources(source_root:Path,workspace:Path,recipe,curl_archive:Path,download=False):
    from .stages import run_stage,stage_fingerprint
    fingerprint=source_fingerprint(source_root,recipe)
    artifact_records=[]
    for stage,action in (('adapters',lambda root:build_adapters(source_root,root)),('security',lambda root:build_security(source_root,root)),('curl',lambda root:build_curl(root,recipe,curl_archive))):
        key=stage_fingerprint({'source':fingerprint,'stage':stage,'archive':recipe['curl']['archive_sha256']})
        receipt=run_stage(workspace,stage,key,action)
        artifact_records.extend(receipt['outputs'])
    return artifact_records
