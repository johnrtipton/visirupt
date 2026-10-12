import concurrent.futures
import http.client
import json
from pathlib import Path
import tempfile
import threading
import unittest
from http.server import ThreadingHTTPServer
from server import Store, handler

class PollTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = Path(self.tmp.name) / 'votes.db'
        self.store = Store(self.path)
        self.server = ThreadingHTTPServer(('127.0.0.1', 0), handler(self.store, 'https://visirupt.com'))
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown(); self.server.server_close(); self.tmp.cleanup()

    def request(self, method, path, body=None, cookie=None, origin='https://visirupt.com'):
        c = http.client.HTTPConnection('127.0.0.1', self.server.server_port)
        headers = {'Origin': origin, 'Content-Type': 'application/json'}
        if cookie: headers['Cookie'] = cookie
        c.request(method, path, json.dumps(body) if body is not None else None, headers)
        r = c.getresponse(); result = (r.status, dict(r.getheaders()), json.loads(r.read())); c.close()
        return result

    def test_vote_cookie_duplicate_and_persistence(self):
        status, headers, data = self.request('GET', '/api/polls')
        self.assertEqual(status, 200); self.assertNotIn('Set-Cookie', headers)
        self.assertEqual([p['total'] for p in data['polls']], [0, 0])
        status, headers, data = self.request('POST', '/api/polls/next/vote', {'choice': 'vr'})
        self.assertEqual(status, 200)
        cookie = headers['Set-Cookie'].split(';')[0]
        self.assertIn('Secure', headers['Set-Cookie']); self.assertIn('HttpOnly', headers['Set-Cookie'])
        self.assertEqual(data['polls'][0]['vote'], 'vr')
        data = self.request('POST', '/api/polls/next/vote', {'choice': 'flat'}, cookie)[2]
        self.assertEqual(data['polls'][0]['total'], 1); self.assertEqual(data['polls'][0]['vote'], 'vr')
        self.assertEqual(self.request('GET', '/api/polls', cookie=cookie)[2]['polls'][0]['vote'], 'vr')
        self.assertEqual(Store(self.path).results()['polls'][0]['total'], 1)
        self.assertEqual(self.request('POST', '/api/polls/priority/vote', {'choice': 'stereo'}, cookie)[2]['polls'][1]['total'], 1)

    def test_invalid_and_cross_origin_requests_do_not_vote(self):
        self.assertEqual(self.request('POST', '/api/polls/next/vote', {'choice': 'vr'}, origin='https://other.test')[0], 403)
        for body in [{'choice': 'invalid'}, [], {'choice': None}]:
            self.assertEqual(self.request('POST', '/api/polls/next/vote', body)[0], 400)
        self.assertEqual(self.request('GET', '/api/unknown')[0], 404)
        self.assertEqual(self.store.results()['polls'][0]['total'], 0)

    def test_concurrent_duplicate_votes_count_once(self):
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            list(pool.map(lambda _: self.store.vote('same-voter', 'next', 'vr'), range(20)))
        self.assertEqual(self.store.results()['polls'][0]['total'], 1)
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            list(pool.map(lambda n: self.store.vote(str(n), 'next', 'flat'), range(20)))
        self.assertEqual(self.store.results()['polls'][0]['total'], 21)

if __name__ == '__main__': unittest.main()
