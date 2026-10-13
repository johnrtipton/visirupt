"""Explicit foreground/background orchestration over the reviewed receiver protocol."""
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time
from types import SimpleNamespace
from .core import ROOT,PipelineError,identify_game
from .workspace import atomic_json,checked_workspace
from .stages import run_stage,read_receipt,validate_receipt,stage_fingerprint
from .assets import build_asset_manifest,verify_asset_manifest,original_root
from .transfer import device_writer_lock,owner_id,verify_native_completion,BUNDLE

def legacy(name):
    path=ROOT/'cyberpunk-avp/resumable'/(name+'.py')
    spec=importlib.util.spec_from_file_location('_visirupt_'+name,path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module

def asset_manifest(workspace,recipe,game_root):
    identify_game(game_root,recipe)
    fingerprint=stage_fingerprint({'recipe':recipe,'source_root':str(game_root.resolve())})
    def prepare(root):
        output=root/'asset-manifest.json';build_asset_manifest(game_root,output,recipe)
        return [output,root/'inputUserMappings.original.xml',root/'inputUserMappings.prepared.xml']
    receipt=run_stage(workspace,'assets',fingerprint,prepare)
    manifest=next(workspace/a['path'] for a in receipt['outputs'] if Path(a['path']).name=='asset-manifest.json')
    result=json.loads(manifest.read_text())
    if result.get('recipe')!=recipe['id'] or result.get('recipe_version')!=recipe['version']:raise PipelineError('INVALID_RECEIPT')
    verify_asset_manifest(result,game_root)
    return manifest

def stop_owned(process):
    if process.poll() is None:
        try:os.killpg(process.pid,signal.SIGTERM)
        except ProcessLookupError:pass
        try:process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            try:os.killpg(process.pid,signal.SIGKILL)
            except ProcessLookupError:pass
            process.wait()

def background_transfer(client,manifest,source,root,owner,interface):
    bg=legacy('background_transfer')
    interface=bg.interface_address(interface)
    if interface.startswith('127.'):raise PipelineError('UNSUPPORTED_INPUT','background receiver requires a reachable local interface')
    checkpoints=root/'native-checkpoints';checkpoints.mkdir(mode=0o700,exist_ok=True)
    client.acquire()
    initial=client.status()
    client.copy_from('Library/Application Support/GameData/.checkpoints',checkpoints)
    plan=root.parent/'background-transfer-plan.json'
    args=SimpleNamespace(asset_root=source,manifest=manifest,checkpoints=checkpoints,plan=plan,owner_id=owner,interface=interface)
    if plan.exists():
        saved=json.loads(plan.read_text())
        if saved.get('owner_id')!=owner:raise PipelineError('DEVICE_BUSY','background plan belongs to another workspace')
        assets={a['relative_path']:a for a in json.loads(manifest.read_text())['files']}
        for job in saved['jobs']:
            if job.get('owner_id')!=owner or job.get('asset_path') not in assets:raise PipelineError('INVALID_RECEIPT','background plan identity')
    else:bg.prepare(args)
    jobs=json.loads(plan.read_text())['jobs']
    client.copy_to(plan,'Documents/background-transfer-plan.json')
    if not jobs:
        complete=client.status();verify_native_completion(complete,json.loads(manifest.read_text()));client.release();return complete
    log=root/'server.log'
    with log.open('wb') as output:
        log.chmod(0o600)
        process=subprocess.Popen([sys.executable,str(ROOT/'cyberpunk-avp/resumable/background_transfer.py'),'serve','--asset-root',str(source),'--manifest',str(manifest),'--plan',str(plan),'--owner-id',owner,'--interface',interface],stdout=output,stderr=subprocess.STDOUT,start_new_session=True)
        try:
            # A failed server must never masquerade as a completed transfer.
            receipts=root/'background-receipts';receipts.mkdir(mode=0o700,exist_ok=True)
            while True:
                if process.poll() is not None:raise PipelineError('INCOMPLETE_TRANSFER','owned range server stopped')
                try:client.copy_from('Documents/BackgroundReceipts',receipts)
                except PipelineError:time.sleep(5);continue
                complete=True
                for job in jobs:
                    path=receipts/(job['request_id']+'.json')
                    if not path.exists():complete=False;break
                    result=json.loads(path.read_text())
                    if result.get('request_id')!=job['request_id']:raise PipelineError('INCOMPLETE_TRANSFER','background receipt identifier')
                    if result.get('state')=='rejected':raise PipelineError('INCOMPLETE_TRANSFER','background chunk rejected; private diagnostics retained')
                    if result.get('state')!='accepted':complete=False;break
                if complete:
                    snapshot=client.status();verify_native_completion(snapshot,json.loads(manifest.read_text()))
                    client.release();return snapshot
                time.sleep(5)
        finally:stop_owned(process)

def transfer_assets(workspace:Path,recipe,device:str,transport:str,deploy_receiver=False,*,game_root:Path|None=None,interface=None,team=None,launch_receiver=False):
    if transport not in ('foreground','background') or game_root is None:raise PipelineError('UNSUPPORTED_INPUT','explicit --transport and --game required')
    if deploy_receiver and not team:raise PipelineError('UNSUPPORTED_INPUT','--team required for receiver deployment')
    if launch_receiver and not deploy_receiver:raise PipelineError('UNSUPPORTED_INPUT','--launch-receiver requires explicit receiver deployment')
    if transport=='background' and not interface:raise PipelineError('UNSUPPORTED_INPUT','--interface required for background transfer')
    checked_workspace(workspace,[ROOT,game_root])
    manifest=asset_manifest(workspace,recipe,game_root)
    if deploy_receiver:
        from .device import deploy_receiver_app
        deploy_receiver_app(workspace,recipe,device,manifest,team)
    elif launch_receiver:raise PipelineError('UNSUPPORTED_INPUT','launch receiver requires explicit deployment')
    if launch_receiver:
        from .device import launch_receiver_app
        launch_receiver_app(workspace,device)
    from .device import require_receiver_installation
    owned_receiver=require_receiver_installation(workspace,device)
    device=owned_receiver['device']
    # No automatic launch. Without an explicitly running receiver, native requests time out safely.
    fg=legacy('transfer');owner=owner_id(workspace)
    fingerprint=stage_fingerprint({'recipe':recipe,'manifest':json.loads(manifest.read_text()),'device':device,'transport':transport})
    with device_writer_lock(device,BUNDLE,workspace):
        def action(root):
            client=fg.TransferClient(device,root/'packets',manifest,owner,transport=transport)
            if transport=='foreground':snapshot=client.transfer(original_root(game_root),256*1024*1024)
            else:snapshot=background_transfer(client,manifest,original_root(game_root),root,owner,interface)
            verify_native_completion(snapshot,json.loads(manifest.read_text()))
            atomic_json(root/'native-completion.json',snapshot)
            return [root/'native-completion.json']
        receipt=run_stage(workspace,'transfer',fingerprint,action)
        # Cached local receipts never substitute for current native verification.
        client=fg.TransferClient(device,workspace/'TransferVerification',manifest,owner,transport=transport)
        snapshot=client.status();verify_native_completion(snapshot,json.loads(manifest.read_text()))
        client.release()
        return receipt
