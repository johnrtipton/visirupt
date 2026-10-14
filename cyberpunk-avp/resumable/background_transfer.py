"""Prepare and serve an immutable batch of remaining original asset ranges.

The plan contains a bearer secret: keep it private and never print its contents.
No game files are modified or copied into a second large staging tree.
"""
import argparse
import hashlib
import hmac
import http.server
import json
import pathlib
import secrets
import subprocess
import uuid
import ipaddress
import os
import sys
ROOT=pathlib.Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT.parents[1]))
from tools.visirupt_pipeline.transfer import source_file
from tools.visirupt_pipeline.workspace import checked_workspace
from tools.visirupt_pipeline.core import PipelineError


CHUNK = 256 * 1024 * 1024


def ranges(asset, checkpoint):
    offset = 0
    if checkpoint:
        if checkpoint['source_sha256'] != asset['sha256']:
            raise ValueError('Checkpoint source mismatch')
        offset = checkpoint['offset']
        if not 0 <= offset <= asset['bytes']:
            raise ValueError('Checkpoint offset out of range')
        if checkpoint['verified']:
            if offset != asset['bytes']:
                raise ValueError('Invalid verified checkpoint')
            return []
        end = 0
        for chunk in checkpoint['chunks']:
            if chunk['offset'] != end or not 0 < chunk['bytes'] <= CHUNK:
                raise ValueError('Invalid checkpoint chunk layout')
            end += chunk['bytes']
        if end != offset:
            raise ValueError('Invalid checkpoint end')
    return [(position, min(CHUNK, asset['bytes'] - position))
            for position in range(offset, asset['bytes'], CHUNK)]


def prepare(args):
    source = args.asset_root.resolve()
    manifest = json.loads(args.manifest.read_text())['files']
    host = interface_address(args.interface)
    uuid.UUID(args.owner_id)
    token = secrets.token_hex(32)
    jobs = []
    if args.plan.exists():
        raise ValueError('Plan already exists; preserve it for resumption')
    for asset in manifest:
        path = asset['relative_path']
        if not path.startswith('Data/'):
            continue
        file = source_file(source, asset, args.manifest)
        if file.stat().st_size != asset['bytes']:
            raise ValueError('Unexpected source asset')
        key = hashlib.sha256(path.encode()).hexdigest()
        checkpoint_file = args.checkpoints / (key + '.json')
        checkpoint = json.loads(checkpoint_file.read_text()) if checkpoint_file.exists() else None
        todo = ranges(asset, checkpoint)
        with file.open('rb') as handle:
            for offset, size in todo:
                handle.seek(offset)
                digest = hashlib.sha256()
                left = size
                while left:
                    data = handle.read(min(left, 1024 * 1024))
                    if not data:
                        raise ValueError('Truncated original source')
                    digest.update(data)
                    left -= len(data)
                request = str(uuid.uuid4())
                jobs.append(dict(request_id=request, url=f'http://{host}:8875/asset/{request}',
                                 token=token, owner_id=args.owner_id, bytes=size, sha256=digest.hexdigest(),
                                 asset_path=path, offset=offset))
        print(f'Prepared {len(todo)} remaining chunks: {path}', flush=True)
    plan = {'owner_id':args.owner_id, 'jobs': jobs, 'remaining_bytes': sum(job['bytes'] for job in jobs)}
    checked_workspace(args.plan, [])
    args.plan.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
    # Exclusive creation, private permissions from the first byte.
    import os
    with os.fdopen(os.open(args.plan, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), 'w') as handle:
        json.dump(plan, handle)
    print(f'Batch ready: {len(jobs)} chunks, {plan["remaining_bytes"] / 2**30:.2f} GiB', flush=True)


def interface_address(value):
    if not value:
        raise PipelineError('UNSUPPORTED_INPUT','explicit local interface/address required')
    if value.startswith('en') and value[2:].isdigit():
        value=subprocess.check_output(['ipconfig','getifaddr',value],text=True).strip()
    address=ipaddress.ip_address(value)
    if address.version!=4 or not (address.is_private or address.is_loopback):
        raise PipelineError('UNSUPPORTED_INPUT','local IPv4 interface required')
    return str(address)


def make_server(args):
    jobs=json.loads(args.plan.read_text())['jobs']
    if len(jobs)>10000:raise PipelineError('UNSUPPORTED_INPUT','job count')
    manifest=json.loads(args.manifest.read_text())['files']
    assets={asset['relative_path']:asset for asset in manifest}
    index={}
    source=args.asset_root.resolve()
    for job in jobs:
        uuid.UUID(job['request_id'])
        asset=assets.get(job['asset_path'])
        if not asset or not isinstance(job['offset'],int) or not isinstance(job['bytes'],int) or job['offset']<0 or not 0<job['bytes']<=CHUNK or job['offset']+job['bytes']>asset['bytes']:
            raise PipelineError('UNSUPPORTED_INPUT','unlisted or invalid range')
        path=source_file(source,asset,args.manifest)
        if path.stat().st_size!=asset['bytes']:raise PipelineError('SOURCE_CHANGED')
        key='/asset/'+job['request_id']
        if key in index:raise PipelineError('UNSUPPORTED_INPUT','duplicate request identifier')
        index[key]=(job,asset)
    ip=interface_address(args.interface)
    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self,*_):pass
        def do_GET(self):
            selected=index.get(self.path)
            if not selected or not hmac.compare_digest(self.headers.get('Authorization',''),'Bearer '+selected[0]['token']):
                self.send_error(404);return
            job,asset=selected;start=0;header=self.headers.get('Range')
            if header:
                try:
                    if not header.startswith('bytes=') or not header.endswith('-'):raise ValueError()
                    start=int(header[6:-1])
                    if not 0<=start<job['bytes']:raise ValueError()
                except ValueError:self.send_error(416);return
            try:
                file=source_file(source,asset,args.manifest)
                stream=file.open('rb')
            except (OSError,ValueError):self.send_error(404);return
            with stream:
                before=os.fstat(stream.fileno())
                if before.st_size!=asset['bytes']:self.send_error(409);return
                self.send_response(206 if start else 200)
                self.send_header('Content-Length',str(job['bytes']-start));self.send_header('Accept-Ranges','bytes')
                self.send_header('ETag','"'+job['sha256']+'"');self.send_header('Content-Type','application/octet-stream')
                if start:self.send_header('Content-Range',f'bytes {start}-{job["bytes"]-1}/{job["bytes"]}')
                self.end_headers()
                try:
                    stream.seek(job['offset']+start);left=job['bytes']-start
                    while left:
                        data=stream.read(min(left,1024*1024))
                        if not data:raise ValueError('Source ended early')
                        self.wfile.write(data);left-=len(data)
                    after=os.fstat(stream.fileno())
                    if (before.st_size,before.st_mtime_ns,before.st_ctime_ns)!=(after.st_size,after.st_mtime_ns,after.st_ctime_ns):
                        raise ValueError('Source changed during range')
                except (BrokenPipeError,ConnectionResetError,OSError,ValueError):
                    self.close_connection=True
    return http.server.ThreadingHTTPServer((ip,getattr(args,'port',8875)),Handler)


def serve(args):
    server=make_server(args)
    print('Private authenticated asset server ready',flush=True)
    try:server.serve_forever()
    finally:server.server_close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['prepare', 'serve'])
    parser.add_argument('--asset-root', type=pathlib.Path, required=True)
    parser.add_argument('--plan', type=pathlib.Path, required=True)
    parser.add_argument('--checkpoints', type=pathlib.Path)
    parser.add_argument('--owner-id',required=True)
    parser.add_argument('--interface',required=True)
    parser.add_argument('--port',type=int,default=8875)
    parser.add_argument('--manifest', type=pathlib.Path, default=pathlib.Path(__file__).parent / 'Resources/asset-manifest.json')
    args = parser.parse_args()
    if args.action == 'prepare' and args.checkpoints is None:
        parser.error('prepare requires --checkpoints')
    (prepare if args.action == 'prepare' else serve)(args)


if __name__ == '__main__':
    main()
