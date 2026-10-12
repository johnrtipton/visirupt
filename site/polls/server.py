"""Anonymous community polls. No names, IP addresses or request logs stored."""
import hashlib
import json
import os
import re
import secrets
import sqlite3
from http.cookies import SimpleCookie
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

POLLS = [
    {"id": "next", "question": "What would you like to bring to Vision Pro?", "options": [
        {"id": "productivity", "label": "Productivity apps"},
        {"id": "creative", "label": "Creative apps"},
        {"id": "flat", "label": "More native games"},
        {"id": "vr", "label": "Immersive VR games"}]},
    {"id": "priority", "question": "What should we prioritize next?", "options": [
        {"id": "install", "label": "An easier installation process"},
        {"id": "graphics", "label": "Sharper graphics and performance"},
        {"id": "stereo", "label": "Stereo VR and head tracking"},
        {"id": "controllers", "label": "VR controller support"}]}]

class Store:
    def __init__(self, path):
        self.path = str(path)
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        with self.connect() as db:
            db.execute('CREATE TABLE IF NOT EXISTS votes (voter TEXT, poll TEXT, choice TEXT, PRIMARY KEY (voter, poll))')

    def connect(self):
        return sqlite3.connect(self.path, timeout=10)

    def results(self, voter=None):
        with self.connect() as db:
            counts = {(p, c): n for p, c, n in db.execute('SELECT poll, choice, COUNT(*) FROM votes GROUP BY poll, choice')}
            mine = dict(db.execute('SELECT poll, choice FROM votes WHERE voter=?', (voter,))) if voter else {}
        return {"polls": [{**p, "options": [{**o, "votes": counts.get((p['id'], o['id']), 0)} for o in p['options']],
                           "total": sum(counts.get((p['id'], o['id']), 0) for o in p['options']),
                           "vote": mine.get(p['id'])} for p in POLLS]}

    def vote(self, voter, poll, choice):
        if not any(p['id'] == poll and any(o['id'] == choice for o in p['options']) for p in POLLS):
            raise ValueError('Choose a valid poll option.')
        with self.connect() as db:
            db.execute('INSERT OR IGNORE INTO votes VALUES (?, ?, ?)', (voter, poll, choice))
        return self.results(voter)


def handler(store, origin):
    class Handler(BaseHTTPRequestHandler):
        server_version = 'Visirupt'
        def setup(self):
            super().setup()
            self.connection.settimeout(10)

        def log_message(self, *args):
            pass

        def identity(self):
            cookie = SimpleCookie()
            try:
                cookie.load(self.headers.get('Cookie', ''))
                token = cookie.get('visirupt_vote')
                token = token.value if token else None
            except Exception:
                token = None
            if token and re.fullmatch(r'[0-9a-f]{64}', token):
                return token, hashlib.sha256(token.encode()).hexdigest()
            return None, None

        def respond(self, status, data, token=None):
            body = json.dumps(data).encode()
            self.send_response(status)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.send_header('Cache-Control', 'no-store')
            self.send_header('X-Content-Type-Options', 'nosniff')
            if token:
                secure = '; Secure' if origin.startswith('https://') else ''
                self.send_header('Set-Cookie', f'visirupt_vote={token}; Path=/api/; Max-Age=31536000; HttpOnly; SameSite=Lax{secure}')
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            if self.path == '/healthz':
                return self.respond(200, {'ok': True})
            if self.path != '/api/polls':
                return self.respond(404, {'error': 'Not found.'})
            self.respond(200, store.results(self.identity()[1]))

        def do_POST(self):
            if self.headers.get('Origin') != origin:
                return self.respond(403, {'error': 'Please vote from the Visirupt website.'})
            match = re.fullmatch(r'/api/polls/(next|priority)/vote', self.path)
            if not match:
                return self.respond(404, {'error': 'Not found.'})
            if self.headers.get('Content-Type', '').split(';')[0] != 'application/json':
                return self.respond(415, {'error': 'JSON required.'})
            try:
                length = int(self.headers.get('Content-Length', '0'))
                if not 0 < length <= 256:
                    return self.respond(413, {'error': 'Invalid request size.'})
                data = json.loads(self.rfile.read(length))
                if not isinstance(data, dict) or not isinstance(data.get('choice'), str):
                    raise ValueError('Choose a valid poll option.')
                token, voter = self.identity()
                new = not token
                if new:
                    token = secrets.token_hex(32)
                    voter = hashlib.sha256(token.encode()).hexdigest()
                results = store.vote(voter, match[1], data['choice'])
            except (ValueError, UnicodeDecodeError):
                return self.respond(400, {'error': 'Choose a valid poll option.'})
            self.respond(200, results, token if new else None)
    return Handler

if __name__ == '__main__':
    store = Store(os.environ.get('POLL_DB', '/data/polls.sqlite3'))
    server = ThreadingHTTPServer(('0.0.0.0', int(os.environ.get('PORT', '8081'))), handler(store, os.environ.get('POLL_ORIGIN', 'https://visirupt.com')))
    server.timeout = 10
    server.serve_forever()
