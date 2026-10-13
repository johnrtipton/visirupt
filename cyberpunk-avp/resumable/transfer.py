#!/usr/bin/env python3
"""Explicit-device transfer in verified packets with native writer ownership."""
import argparse
import hashlib
import json
import pathlib
import sys
import time
import uuid
ROOT=pathlib.Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT.parents[1]))
from tools.visirupt_pipeline.core import PipelineError
from tools.visirupt_pipeline.runner import run_tool
from tools.visirupt_pipeline.workspace import private_directory,atomic_json,checked_workspace
from tools.visirupt_pipeline.transfer import source_file,device_writer_lock,owner_id,verify_native_completion
BUNDLE='local.games.cyberpunk.assetreceiver'

class TransferClient:
    def __init__(self,device,work,manifest,owner,timeout=600,transport="foreground"):
        self.device=device;self.work=pathlib.Path(work);self.manifest=pathlib.Path(manifest);self.owner=owner;self.timeout=timeout;self.transport=transport
        private_directory(self.work)
    def command(self,label,args):
        receipt=self.work/(label+'-'+uuid.uuid4().hex+'.json')
        run_tool(['xcrun','devicectl',*args,'--timeout','120','--json-output',str(receipt)],self.work,self.work/(label+'.log'),150)
        if not receipt.is_file():raise PipelineError('TOOL_FAILED','device receipt missing')
        value=json.loads(receipt.read_text())
        if value.get('error') or value.get('outcome')=='failed':raise PipelineError('TOOL_FAILED','device operation failed')
        return value
    def copy_to(self,source,destination):
        return self.command('copy-to',['device','copy','to','--device',self.device,'--domain-type','appDataContainer','--domain-identifier',BUNDLE,'--source',str(source),'--destination',destination])
    def copy_from(self,source,destination):
        return self.command('copy-from',['device','copy','from','--device',self.device,'--domain-type','appDataContainer','--domain-identifier',BUNDLE,'--source',source,'--destination',str(destination)])
    def exchange(self,request,payload=None):
        request=dict(request,request_id=str(uuid.uuid4()),owner_id=self.owner,transport=self.transport)
        packet=self.work/request['request_id'];private_directory(packet)
        if payload is not None:
            local=packet/'payload.bin'
            with local.open('xb') as output:output.write(payload)
            local.chmod(0o600)
            request['bytes']=len(payload)
            self.copy_to(local,'Documents/TransferInbox/payload.bin')
        atomic_json(packet/'request.json',request)
        self.copy_to(packet/'request.json','Documents/TransferInbox/request.json')
        deadline=time.monotonic()+self.timeout
        while time.monotonic()<deadline:
            response=packet/'receipt.json'
            try:
                self.copy_from('Documents/transfer-results.json',response)
                result=json.loads(response.read_text())
            except (OSError,ValueError):
                time.sleep(2);continue
            if result.get('request_id')==request['request_id']:
                if result.get('state')!='accepted':raise PipelineError('DEVICE_BUSY' if request['action'].startswith('lease_') else 'INCOMPLETE_TRANSFER','native receiver rejected request')
                if payload is not None:(packet/'payload.bin').unlink()
                return result
            time.sleep(2)
        raise PipelineError('INCOMPLETE_TRANSFER','native acknowledgement timeout; committed bytes retained')
    def acquire(self):return self.exchange({'action':'lease_acquire'})
    def release(self):return self.exchange({'action':'lease_release'})
    def status(self):
        self.acquire()
        return self.exchange({'action':'status'})
    def transfer(self,asset_root,chunk_bytes):
        manifest=json.loads(self.manifest.read_text());snapshot=self.status();status=snapshot['files']
        if set(status)!={a['relative_path'] for a in manifest['files']}:raise PipelineError('INCOMPLETE_TRANSFER','manifest differs from native receiver')
        needed=sum(a['bytes']-status[a['relative_path']]['offset'] for a in manifest['files'])
        if needed<0 or snapshot.get('available_disk_bytes',0)<needed+2*chunk_bytes+512*1024*1024:raise PipelineError('INCOMPLETE_TRANSFER','native capacity')
        for asset in manifest['files']:
            name=asset['relative_path'];cp=status[name]
            if cp.get('source_sha256')!=asset['sha256']:raise PipelineError('INCOMPLETE_TRANSFER','native source identity')
            if cp.get('verified'):
                if cp['offset']!=asset['bytes']:raise PipelineError('INCOMPLETE_TRANSFER','native size')
                continue
            source=source_file(asset_root,asset,self.manifest)
            if source.stat().st_size!=asset['bytes']:raise PipelineError('SOURCE_CHANGED')
            offset=cp['offset']
            with source.open('rb') as stream:
                stream.seek(offset)
                while offset<asset['bytes']:
                    self.acquire()
                    payload=stream.read(min(chunk_bytes,asset['bytes']-offset))
                    if not payload:raise PipelineError('SOURCE_CHANGED')
                    response=self.exchange({'action':'accept','path':name,'offset':offset,'chunk_sha256':hashlib.sha256(payload).hexdigest()},payload)
                    cp=response['checkpoint']
                    if cp['offset']!=offset+len(payload):raise PipelineError('INCOMPLETE_TRANSFER','native checkpoint offset')
                    offset=cp['offset']
            if cp.get('verified') is not True:raise PipelineError('INCOMPLETE_TRANSFER','native whole-file hash')
        result=self.status();verify_native_completion(result,manifest)
        atomic_json(self.work/'native-completion.json',result)
        self.release()
        return result

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('mode',choices=['assets'])
    p.add_argument('--device',required=True);p.add_argument('--work',type=pathlib.Path,required=True)
    p.add_argument('--manifest',type=pathlib.Path,required=True);p.add_argument('--asset-root',type=pathlib.Path,required=True)
    p.add_argument('--chunk-mib',type=int,default=256)
    args=p.parse_args()
    if not 1<=args.chunk_mib<=256:p.error('chunk size must be 1..256 MiB')
    checked_workspace(args.work,[ROOT.parents[1],args.asset_root])
    with device_writer_lock(args.device,BUNDLE,args.work):
        client=TransferClient(args.device,args.work,args.manifest,owner_id(args.work))
        result=client.transfer(args.asset_root,args.chunk_mib*1024*1024)
        print(json.dumps(verify_native_completion(result,json.loads(args.manifest.read_text()))))
if __name__=='__main__':main()
