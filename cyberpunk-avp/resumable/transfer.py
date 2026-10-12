#!/usr/bin/env python3
"""Transfer original data in verified chunks; receiver checkpoints are authoritative."""
import argparse, hashlib, json, pathlib, subprocess, time, uuid
ROOT = pathlib.Path(__file__).resolve().parent
DEVICE = '36A3F463-4C46-5BE2-9AF8-F3EB3A2F4B45'
BUNDLE = 'local.games.cyberpunk.assetreceiver'
WORK = ROOT.parents[1] / 'scratch/cyberpunk-resumable/transfer'
WORK.mkdir(parents=True, exist_ok=True)

def command(label, args):
    log = WORK / (label + '.log')
    with log.open('w') as output:
        p = subprocess.run(['xcrun', 'devicectl'] + args + ['--timeout', '120', '--json-output', str(WORK / (label + '.json'))], stdout=output, stderr=subprocess.STDOUT, timeout=150)
    if p.returncode:
        raise RuntimeError(f'{label} failed; progress on device is retained. See {log}')

def exchange(request, payload=None):
    request['request_id'] = str(uuid.uuid4())
    packet = WORK / request['request_id']; packet.mkdir()
    if payload is not None:
        local = packet / 'payload.bin'; local.write_bytes(payload)
        command('copy-payload', ['device','copy','to','--device',DEVICE,'--domain-type','appDataContainer','--domain-identifier',BUNDLE,'--source',str(local),'--destination','Documents/TransferInbox/payload.bin'])
    local = packet / 'request.json'; local.write_text(json.dumps(request))
    command('copy-request', ['device','copy','to','--device',DEVICE,'--domain-type','appDataContainer','--domain-identifier',BUNDLE,'--source',str(local),'--destination','Documents/TransferInbox/request.json'])
    deadline = time.monotonic() + 600
    while time.monotonic() < deadline:
        response = packet / 'receipt.json'
        try:
            command('fetch-receipt', ['device','copy','from','--device',DEVICE,'--domain-type','appDataContainer','--domain-identifier',BUNDLE,'--source','Documents/transfer-results.json','--destination',str(response)])
        except (RuntimeError, subprocess.TimeoutExpired):
            time.sleep(2)
            continue
        result = json.loads(response.read_text())
        if result.get('request_id') == request['request_id']:
            if result.get('state') != 'accepted': raise RuntimeError('Receiver rejected packet: '+str(result.get('error')))
            if payload is not None: (packet / 'payload.bin').unlink()
            return result
        time.sleep(2)
    raise RuntimeError('Receiver did not acknowledge packet; keep its window open and retry. Saved chunks remain on device.')

def transfer(mode, asset_root, chunk_bytes):
    manifest = json.loads((ROOT/'Resources/asset-manifest.json').read_text())['files']
    snapshot = exchange({'action':'status'})
    status = snapshot['files']
    files = [a for a in manifest if a['relative_path'].startswith('Data/')] if mode == 'assets' else [a for a in manifest if a['relative_path']=='Probe/test-data.bin']
    if mode == 'assets':
        needed = sum(a['bytes'] - status[a['relative_path']]['offset'] for a in files)
        if snapshot['available_disk_bytes'] < needed + 2 * chunk_bytes + 512 * 1024 * 1024:
            raise RuntimeError('Insufficient headset free space for remaining assets and temporary chunks')
    report = {'mode':mode,'stage':'transferring','files':[],'game_code_executed':False}
    for asset in files:
        name = asset['relative_path']; cp = status[name]
        if cp['source_sha256'] != asset['sha256']: raise RuntimeError('Receiver source manifest differs')
        if cp['verified']:
            report['files'].append({'path':name,'state':'already_verified','bytes':cp['offset']}); continue
        if mode == 'probe-first' and cp['offset'] != 0: raise RuntimeError('First-phase probe requires an unused fixture')
        if mode == 'probe-finish' and cp['offset'] != 1048576: raise RuntimeError('Restart did not retain the expected first MiB')
        source = ROOT.parents[1]/'scratch/cyberpunk-resumable/probe-original.bin' if mode.startswith('probe-') else asset_root/name
        source = source.resolve()
        if mode=='assets' and not source.is_relative_to(asset_root.resolve()): raise RuntimeError('Asset path escapes source root')
        if source.stat().st_size != asset['bytes']: raise RuntimeError('Source asset size changed')
        offset = cp['offset']; stop = 1048576 if mode=='probe-first' else asset['bytes']
        with source.open('rb') as stream:
            stream.seek(offset)
            while offset < stop:
                payload = stream.read(min(chunk_bytes,stop-offset))
                if not payload: raise RuntimeError('Source ended early')
                response = exchange({'action':'accept','path':name,'offset':offset,'chunk_sha256':hashlib.sha256(payload).hexdigest()},payload)
                cp = response['checkpoint']
                if cp['offset'] != offset+len(payload): raise RuntimeError('Receiver offset does not match verified payload')
                offset=cp['offset']
                report['current']={'path':name,'verified_offset':offset,'file_complete':cp['verified']}
                (WORK/'progress.json').write_text(json.dumps(report,indent=2)+'\n')
        if mode!='probe-first' and not cp['verified']: raise RuntimeError('Complete original SHA256 not verified')
        report['files'].append({'path':name,'verified_offset':offset,'file_complete':cp['verified']})
    report['stage']='phase_complete'
    (WORK/('result-'+mode+'.json')).write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('mode',choices=['probe-first','probe-finish','assets'])
    parser.add_argument('--asset-root',type=pathlib.Path)
    parser.add_argument('--chunk-mib',type=int,default=256)
    args=parser.parse_args()
    if not 1<=args.chunk_mib<=256: parser.error('chunk size must be between 1 and 256 MiB')
    if args.mode=='assets' and args.asset_root is None: parser.error('--asset-root is required')
    transfer(args.mode,args.asset_root,args.chunk_mib*1024*1024)
