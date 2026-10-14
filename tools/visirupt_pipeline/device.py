"""Explicit device operations with current-state and preserved-container gates."""
import json
from pathlib import Path
import plistlib
import shutil
from urllib.parse import urlsplit,unquote
import uuid
from .core import ROOT,PipelineError,sha256
from .workspace import checked_workspace,private_directory,atomic_json
from .runner import run_tool
from .host import inspect_signed_app,verify_embedded,validate_signing_team,BUNDLE
from .stages import read_receipt,validate_receipt,stage_fingerprint,run_stage
from .transfer import device_writer_lock


def selector(value):
    if not isinstance(value,str) or not value or value.startswith('-') or len(value)>256 or any(c in value for c in '\0\r\n'):
        raise PipelineError('UNSUPPORTED_INPUT','explicit device selector')
    return value

def command(workspace,argv,runner=run_tool):
    private_directory(workspace/'DeviceDiagnostics')
    output=workspace/'DeviceDiagnostics'/('result-'+uuid.uuid4().hex+'.json')
    runner(['xcrun','devicectl',*argv,'--timeout','120','--json-output',str(output)],workspace,output.with_suffix('.log'),150)
    if not output.is_file():raise PipelineError('TOOL_FAILED','device receipt missing')
    value=json.loads(output.read_text())
    if not isinstance(value,dict) or value.get('info',{}).get('outcome')!='success' or not isinstance(value.get('result'),dict):
        raise PipelineError('TOOL_FAILED','device command did not complete')
    output.chmod(0o600)
    return value['result']

def normalized_url(value):
    if not isinstance(value,str):return None
    parsed=urlsplit(value)
    if parsed.scheme!='file' or parsed.netloc not in ('','localhost') or not parsed.path:return None
    path=unquote(parsed.path)
    if '..' in Path(path).parts or not path.endswith('.app'):return None
    return path.rstrip('/')

def inspect_device(device:str,bundle:str,*,workspace:Path,runner=run_tool) -> dict:
    selector(device);checked_workspace(workspace,[ROOT])
    result=command(workspace,['device','info','apps','--device',device],runner)
    apps=result.get('apps');canonical=result.get('deviceIdentifier')
    if not isinstance(apps,list) or not isinstance(canonical,str) or not canonical:raise PipelineError('UNSUPPORTED_INPUT','unsupported device-app schema')
    selected=[app for app in apps if isinstance(app,dict) and app.get('bundleIdentifier')==bundle]
    if len(selected)>1:raise PipelineError('UNSUPPORTED_INPUT','ambiguous app identity')
    if not selected:return {'exists':False,'device':canonical,'bundle_identifier':bundle}
    app=selected[0];info={'exists':True,'device':canonical,'bundle_identifier':bundle,
         'bundle_url':app.get('url'),'data_container':app.get('dataContainerPath'),
         'built_by_developer':app.get('builtByDeveloper') is True,'container_accessible':app.get('containerAccessible') is True}
    # This SDK lists container URLs, but not live signing entitlements. Never invent them.
    # Only our own completed, normally signed installation can establish provenance.
    proof=workspace/'installed-device.json';checked_workspace(proof,[])
    if proof.is_file():
        stored=json.loads(proof.read_text())
        if stored.get('device')==canonical and normalized_url(stored.get('bundle_url')) is not None and normalized_url(stored.get('bundle_url'))==normalized_url(info['bundle_url']) and info['built_by_developer'] and info['container_accessible']:
            identity=stored.get('identity')
            if isinstance(identity,dict) and identity.get('signature_verified') is True and identity.get('provisioning_verified') is True and identity.get('bundle_identifier')==bundle:
                info.update(identity);info['kind']=stored.get('kind')
                if stored.get('data_container') and stored['data_container']!=info['data_container']:
                    raise PipelineError('CONTAINER_OWNERSHIP_UNKNOWN','data container changed')
    return info

def require_update_ownership(installed:dict,candidate:dict) -> None:
    if candidate.get('signature_verified') is not True or candidate.get('provisioning_verified') is not True:
        raise PipelineError('CONTAINER_OWNERSHIP_UNKNOWN','candidate signing not verified')
    validate_signing_team(candidate.get('team_identifier'))
    if candidate.get('application_identifier')!=candidate['team_identifier']+'.'+BUNDLE or candidate.get('bundle_identifier')!=BUNDLE:
        raise PipelineError('CONTAINER_OWNERSHIP_UNKNOWN','candidate identity')
    if installed.get('exists'):
        if any(not installed.get(key) or installed.get(key)!=candidate.get(key) for key in ('bundle_identifier','application_identifier','team_identifier')):
            raise PipelineError('CONTAINER_OWNERSHIP_UNKNOWN','existing identity is unknown or differs')

def install_host(workspace:Path,device:str,app:Path,*,recipe=None,runner=run_tool,allow_first=False,kind='host'):
    from .core import load_recipe
    recipe=recipe or load_recipe();checked_workspace(workspace,[ROOT]);checked_workspace(app,[])
    candidate=inspect_signed_app(app,recipe,runner=runner)
    if kind=='host':verify_embedded(app,workspace,recipe)
    installed=inspect_device(device,BUNDLE,workspace=workspace,runner=runner)
    require_update_ownership(installed,candidate)
    if not installed['exists'] and not allow_first:raise PipelineError('CONTAINER_OWNERSHIP_UNKNOWN','explicit first receiver deployment required')
    canonical=installed['device']
    with device_writer_lock(canonical,BUNDLE,workspace):
        return _install_locked(workspace,canonical,app,recipe,runner,allow_first,kind,candidate)

def _install_locked(workspace,canonical,app,recipe,runner,allow_first,kind,candidate):
        installed=inspect_device(canonical,BUNDLE,workspace=workspace,runner=runner)
        if installed['device']!=canonical:raise PipelineError('UNSUPPORTED_INPUT','device identity changed')
        require_update_ownership(installed,candidate)
        if not installed['exists'] and not allow_first:raise PipelineError('CONTAINER_OWNERSHIP_UNKNOWN','existing receiver required')
        if kind=='host':verify_embedded(app,workspace,recipe)
        # Recheck signing immediately before the native install; do not trust a stale build receipt.
        if inspect_signed_app(app,recipe,runner=runner)!=candidate:raise PipelineError('SOURCE_CHANGED','candidate changed after verification')
        result=command(workspace,['device','install','app','--device',canonical,str(app)],runner)
        applications=result.get('installedApplications')
        if result.get('deviceIdentifier')!=canonical or not isinstance(applications,list):raise PipelineError('TOOL_FAILED','incomplete installation receipt')
        matches=[a for a in applications if isinstance(a,dict) and a.get('bundleID')==BUNDLE]
        if len(matches)!=1 or normalized_url(matches[0].get('installationURL')) is None:raise PipelineError('TOOL_FAILED','installed app identity missing')
        current=inspect_device(canonical,BUNDLE,workspace=workspace,runner=runner)
        if not current['exists'] or normalized_url(current['bundle_url'])!=normalized_url(matches[0]['installationURL']):raise PipelineError('TOOL_FAILED','installed app not confirmed')
        if installed['exists'] and (not installed.get('data_container') or current.get('data_container')!=installed['data_container']):
            raise PipelineError('CONTAINER_OWNERSHIP_UNKNOWN','update did not retain original container')
        proof={'device':canonical,'bundle_url':current['bundle_url'],'data_container':current.get('data_container'),'identity':candidate,'kind':kind,'app_path':str(app)}
        atomic_json(workspace/'installed-device.json',proof)
        return {'state':'complete','device':canonical,'installation_verified':True,'kind':kind,'gameplay_confirmed':False}

def installed_app(workspace,device,kind,runner=run_tool):
    current=inspect_device(device,BUNDLE,workspace=workspace,runner=runner)
    if not current['exists'] or current.get('kind')!=kind or not current.get('application_identifier'):
        raise PipelineError('CONTAINER_OWNERSHIP_UNKNOWN','no current owned installation proof')
    return current

def launch_owned(workspace,device,kind,runner=run_tool):
    current=installed_app(workspace,device,kind,runner)
    with device_writer_lock(current['device'],BUNDLE,workspace):
        current=installed_app(workspace,current['device'],kind,runner)
        result=command(workspace,['device','process','launch','--device',current['device'],BUNDLE],runner)
    process=result.get('process',{})
    if result.get('deviceIdentifier')!=current['device'] or type(process.get('processIdentifier')) is not int or process['processIdentifier']<=0:
        raise PipelineError('TOOL_FAILED','launch receipt incomplete')
    return {'state':'complete','launch_verified':True,'gameplay_confirmed':False}

def launch_host(workspace:Path,device:str,runner=run_tool):
    from time import time_ns
    receipt=read_receipt(workspace,'install')
    if not receipt or not validate_receipt(workspace,receipt):raise PipelineError('INVALID_RECEIPT','installation stage missing')
    def action(root):
        result=launch_owned(workspace,device,'host',runner)
        atomic_json(root/'launch.json',result)
        return [root/'launch.json']
    return run_stage(workspace,'launch',stage_fingerprint({'device':device,'request':time_ns()}),action)

def host_app(workspace):
    receipt=read_receipt(workspace,'host')
    if not receipt or not validate_receipt(workspace,receipt):raise PipelineError('INVALID_RECEIPT','host build not verified')
    identity=next((workspace/a['path'] for a in receipt['outputs'] if Path(a['path']).name=='identity.json'),None)
    if identity is None:raise PipelineError('INVALID_RECEIPT')
    return workspace/json.loads(identity.read_text())['app_path']

def prepare_install_receiver(workspace,recipe,device,manifest,*,deploy_receiver=False,launch_receiver=False,team=None):
    current=inspect_device(device,BUNDLE,workspace=workspace)
    if not current.get('application_identifier') or current.get('kind') not in ('host','receiver'):
        raise PipelineError('CONTAINER_OWNERSHIP_UNKNOWN','owned installation required')
    if deploy_receiver:
        if not launch_receiver or not team:raise PipelineError('UNSUPPORTED_INPUT','verifier update requires --deploy-receiver --launch-receiver --team')
        require_update_ownership(current,{'bundle_identifier':BUNDLE,'application_identifier':team+'.'+BUNDLE,'team_identifier':team,'signature_verified':True,'provisioning_verified':True})
        deploy_receiver_app(workspace,recipe,current['device'],manifest,team)
        launch_receiver_app(workspace,current['device'])
    elif current.get('kind')=='host' or launch_receiver:
        raise PipelineError('UNSUPPORTED_INPUT','host update requires explicit verifier: --deploy-receiver --launch-receiver --team')
    return installed_app(workspace,current['device'],'receiver')

def install_prepared_host(workspace,recipe,device,*,deploy_receiver=False,launch_receiver=False,team=None):
    transfer=read_receipt(workspace,'transfer')
    if not transfer or not validate_receipt(workspace,transfer):raise PipelineError('INCOMPLETE_TRANSFER','asset transfer not verified')
    # Revalidate native final hashes, not merely the private completion marker.
    from .transfer_control import legacy
    from .transfer import owner_id,verify_native_completion
    assets=read_receipt(workspace,'assets')
    manifest=next(workspace/a['path'] for a in assets['outputs'] if Path(a['path']).name=='asset-manifest.json')
    current=prepare_install_receiver(workspace,recipe,device,manifest,deploy_receiver=deploy_receiver,launch_receiver=launch_receiver,team=team)
    canonical=current['device']
    def action(root):
        with device_writer_lock(canonical,BUNDLE,workspace):
            fg=legacy('transfer');client=fg.TransferClient(canonical,workspace/'PreinstallNativeVerification',manifest,owner_id(workspace))
            try:
                snapshot=client.status();verify_native_completion(snapshot,json.loads(manifest.read_text()))
            finally:client.release()
            app=host_app(workspace);candidate=inspect_signed_app(app,recipe)
            result=_install_locked(workspace,canonical,app,recipe,run_tool,False,'host',candidate)
        atomic_json(root/'install.json',result)
        return [root/'install.json']
    # Installation is an explicit live operation: never reuse an old local success.
    from time import time_ns
    return run_stage(workspace,'install',stage_fingerprint({'device':canonical,'request':time_ns()}),action)

def deploy_receiver_app(workspace,recipe,device,manifest,team):
    validate_signing_team(team)
    # Check existing ownership before building or replacing any app.
    current=inspect_device(device,BUNDLE,workspace=workspace)
    if current['exists']:
        require_update_ownership(current,{'bundle_identifier':BUNDLE,'application_identifier':team+'.'+BUNDLE,'team_identifier':team,'signature_verified':True,'provisioning_verified':True})
    root=workspace/'ReceiverBuild'/uuid.uuid4().hex;private_directory(root)
    source=ROOT/'cyberpunk-avp/resumable'
    shutil.copytree(source/'Sources',root/'Sources')
    private_directory(root/'Resources');shutil.copy2(manifest,root/'Resources/asset-manifest.json')
    spec=(source/'project.yml').read_text().replace('    GENERATE_INFOPLIST_FILE: YES','    GENERATE_INFOPLIST_FILE: YES\n    CODE_SIGN_ENTITLEMENTS: VirtualAddress.entitlements')
    (root/'project.yml').write_text(spec)
    shutil.copy2(ROOT/'scratch/cyberpunk-staged-startup/VirtualAddress.entitlements',root/'VirtualAddress.entitlements')
    run_tool(['xcodegen','generate','--spec','project.yml'],root,root/'generate.log',120)
    run_tool(['xcodebuild','-project','CyberpunkAssetReceiver.xcodeproj','-scheme','CyberpunkAssetReceiver','-configuration','Debug','-sdk','xros','-destination','generic/platform=visionOS','-derivedDataPath',str(root/'DerivedData'),'DEVELOPMENT_TEAM='+team,'CODE_SIGN_STYLE=Automatic','-allowProvisioningUpdates','build'],root,root/'build.log',1200)
    app=root/'DerivedData/Build/Products/Debug-xros/CyberpunkAssetReceiver.app'
    return install_host(workspace,device,app,recipe=recipe,allow_first=True,kind='receiver')

def launch_receiver_app(workspace,device):return launch_owned(workspace,device,'receiver')

def require_receiver_installation(workspace,device):return installed_app(workspace,device,'receiver')
