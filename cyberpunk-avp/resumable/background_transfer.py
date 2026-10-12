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
    host = subprocess.check_output(['scutil', '--get', 'LocalHostName'], text=True).strip() + '.local'
    token = secrets.token_hex(32)
    jobs = []
    if args.plan.exists():
        raise ValueError('Plan already exists; preserve it for resumption')
    for asset in manifest:
        path = asset['relative_path']
        if not path.startswith('Data/'):
            continue
        file = (source / path).resolve()
        if not file.is_relative_to(source) or file.stat().st_size != asset['bytes']:
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
                                 token=token, bytes=size, sha256=digest.hexdigest(),
                                 asset_path=path, offset=offset))
        print(f'Prepared {len(todo)} remaining chunks: {path}', flush=True)
    plan = {'jobs': jobs, 'remaining_bytes': sum(job['bytes'] for job in jobs)}
    args.plan.parent.mkdir(parents=True, exist_ok=True)
    # Exclusive creation, private permissions from the first byte.
    import os
    with os.fdopen(os.open(args.plan, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), 'w') as handle:
        json.dump(plan, handle)
    print(f'Batch ready: {len(jobs)} chunks, {plan["remaining_bytes"] / 2**30:.2f} GiB', flush=True)


def serve(args):
    jobs = json.loads(args.plan.read_text())['jobs']
    index = {'/asset/' + job['request_id']: job for job in jobs}
    source = args.asset_root.resolve()
    for job in jobs:
        file = (source / job['asset_path']).resolve()
        if not file.is_relative_to(source):
            raise ValueError('Source path escaped root')
    ip = subprocess.check_output(['ipconfig', 'getifaddr', 'en0'], text=True).strip()

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_GET(self):
            job = index.get(self.path)
            if not job or not hmac.compare_digest(self.headers.get('Authorization', ''), 'Bearer ' + job['token']):
                self.send_error(404)
                return
            start = 0
            header = self.headers.get('Range')
            if header:
                try:
                    if not header.startswith('bytes=') or not header.endswith('-'):
                        raise ValueError()
                    start = int(header[6:-1])
                    if not 0 <= start < job['bytes']:
                        raise ValueError()
                except ValueError:
                    self.send_error(416)
                    return
            file = (source / job['asset_path']).resolve()
            if not file.is_relative_to(source):
                self.send_error(404)
                return
            self.send_response(206 if start else 200)
            self.send_header('Content-Length', str(job['bytes'] - start))
            self.send_header('Accept-Ranges', 'bytes')
            self.send_header('ETag', '"' + job['sha256'] + '"')
            self.send_header('Content-Type', 'application/octet-stream')
            if start:
                self.send_header('Content-Range', f'bytes {start}-{job["bytes"]-1}/{job["bytes"]}')
            self.end_headers()
            try:
                with file.open('rb') as handle:
                    handle.seek(job['offset'] + start)
                    left = job['bytes'] - start
                    while left:
                        data = handle.read(min(left, 1024 * 1024))
                        if not data:
                            raise ValueError('Truncated asset')
                        self.wfile.write(data)
                        left -= len(data)
                print(json.dumps(dict(state='sent', request_id=job['request_id'], bytes=job['bytes'], resumed_at=start)), flush=True)
            except (BrokenPipeError, ConnectionResetError):
                print(json.dumps(dict(state='disconnected', request_id=job['request_id'])), flush=True)

    print('Private original-asset batch server ready', flush=True)
    http.server.ThreadingHTTPServer((ip, 8875), Handler).serve_forever()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['prepare', 'serve'])
    parser.add_argument('--asset-root', type=pathlib.Path, required=True)
    parser.add_argument('--plan', type=pathlib.Path, required=True)
    parser.add_argument('--checkpoints', type=pathlib.Path)
    parser.add_argument('--manifest', type=pathlib.Path, default=pathlib.Path(__file__).parent / 'Resources/asset-manifest.json')
    args = parser.parse_args()
    if args.action == 'prepare' and args.checkpoints is None:
        parser.error('prepare requires --checkpoints')
    (prepare if args.action == 'prepare' else serve)(args)


if __name__ == '__main__':
    main()
