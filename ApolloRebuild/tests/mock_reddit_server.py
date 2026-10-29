#!/usr/bin/env python3
"""Local stand-in for Reddit's OAuth + API endpoints, for testing RDKClient and the feed
without a Reddit app. Serves the JSON fixtures in fixtures/ and generated preview images.

    python3 tests/mock_reddit_server.py [--port 8765]
    MOCK_REDDIT=http://127.0.0.1:8765/ scripts/run-in-sim.sh --no-build

Every request is logged (Authorization values redacted). Tokens are fake. Endpoints:
  GET  /api/v1/authorize.compact  redirects straight to redirect_uri with ?state=&code= (as after "Allow")
  POST /api/v1/access_token   installed_client / client_credentials / authorization_code / refresh_token
  POST /api/v1/revoke_token
  GET  /api/v1/me
  GET  /<sort>.json, /r/<name>/<sort>.json, /r/all/<sort>.json, /user/<name>/submitted.json
       (a second page when ?after= is set, then the end of the listing)
  GET  /comments/<id>.json
  POST /api/vote, /api/save, /api/unsave, /api/morechildren
  GET  /img/<w>x<h>/<name>.png   a gradient PNG of that size
"""
import argparse
import base64
import copy
import hashlib
import json
import os
import struct
import sys
import zlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

FIXTURES = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'fixtures')
SORTS = {'hot', 'best', 'new', 'rising', 'controversial', 'top'}


def load(name):
    with open(os.path.join(FIXTURES, name)) as handle:
        return json.load(handle)


def png(width, height, seed):
    """A small gradient PNG (capped at 1200px wide, same aspect) tinted per seed."""
    scale = min(1.0, 1200 / max(width, 1))
    w, h = max(1, int(width * scale)), max(1, int(height * scale))
    digest = hashlib.sha256(seed.encode()).digest()
    r0, g0, b0 = digest[0], digest[1], digest[2]
    rows = bytearray()
    for y in range(h):
        rows.append(0)
        t = y / max(h - 1, 1)
        for x in range(w):
            s = x / max(w - 1, 1)
            rows += bytes(((r0 + int(120 * t)) % 256, (g0 + int(120 * s)) % 256, (b0 + int(60 * (s + t))) % 256))
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(bytes(rows), 6)) + chunk(b'IEND', b'')


def localize_media(value, base):
    """Point every preview {url,width,height} and thumbnail at /img/ on this server."""
    if isinstance(value, dict):
        if {'url', 'width', 'height'} <= value.keys() and isinstance(value['url'], str):
            name = hashlib.sha1(value['url'].encode()).hexdigest()[:10]
            value['url'] = f"{base}img/{value['width']}x{value['height']}/{name}.png"
        if {'u', 'x', 'y'} <= value.keys() and isinstance(value['u'], str):
            # media_metadata image sources (galleries)
            value['u'] = f"{base}img/{value['x']}x{value['y']}/{hashlib.sha1(value['u'].encode()).hexdigest()[:10]}.png"
        if isinstance(value.get('thumbnail'), str) and value['thumbnail'].startswith('http'):
            value['thumbnail'] = f"{base}img/140x105/{hashlib.sha1(value['thumbnail'].encode()).hexdigest()[:10]}.png"
        for child in value.values():
            localize_media(child, base)
    elif isinstance(value, list):
        for child in value:
            localize_media(child, base)
    return value


def second_page(listing):
    """The fixture again with new IDs and no further page."""
    page = copy.deepcopy(listing)
    for child in page['data']['children']:
        data = child['data']
        data['id'] += 'p2'
        data['name'] += 'p2'
        data['title'] = '[Page 2] ' + data['title']
        data['stickied'] = False
    page['data']['after'] = None
    return page


class Handler(BaseHTTPRequestHandler):
    server_version = 'MockReddit/1.0'

    def log_request_line(self, body):
        auth = self.headers.get('Authorization', '')
        scheme = auth.split(' ')[0] if auth else '-'
        if scheme == 'Basic':
            # Whether a client secret (web/script app) came with the client ID; never the value
            try:
                has_secret = bool(base64.b64decode(auth[6:]).decode().partition(':')[2])
            except ValueError:
                has_secret = False
            scheme += '(secret)' if has_secret else '(no secret)'
        print(f"{self.command} {self.path}  auth={scheme}  ua={self.headers.get('User-Agent', '-')}  body={body or '-'}", flush=True)

    def send_json(self, payload, status=200):
        data = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=UTF-8')
        self.send_header('Content-Length', str(len(data)))
        self.send_header('x-ratelimit-remaining', '99.0')
        self.send_header('x-ratelimit-used', '1')
        self.send_header('x-ratelimit-reset', '420')
        self.end_headers()
        self.wfile.write(data)

    def base(self):
        return f"http://{self.headers.get('Host', '127.0.0.1')}/"

    def bearer_ok(self):
        return self.headers.get('Authorization', '').lower().startswith('bearer mock-')

    def do_GET(self):
        self.log_request_line(None)
        url = urlparse(self.path)
        query = parse_qs(url.query)
        parts = [p for p in url.path.split('/') if p]

        if parts[:1] == ['img'] and len(parts) == 3:
            try:
                width, height = (int(v) for v in parts[1].split('x'))
            except ValueError:
                return self.send_json({'error': 404}, 404)
            data = png(width, height, parts[2])
            self.send_response(200)
            self.send_header('Content-Type', 'image/png')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return

        if url.path == '/api/v1/authorize.compact':
            redirect = query.get('redirect_uri', [''])[0]
            state = query.get('state', [''])[0]
            if not redirect or not query.get('client_id'):
                return self.send_json({'error': 'invalid_request'}, 400)
            self.send_response(302)
            self.send_header('Location', f"{redirect}?state={state}&code=mock-code")
            self.end_headers()
            return

        if not self.bearer_ok():
            return self.send_json({'message': 'Unauthorized', 'error': 401}, 401)

        if url.path == '/api/v1/me':
            return self.send_json({'name': 'mock_user', 'id': 'u1', 'link_karma': 1234, 'comment_karma': 5678})

        if parts and parts[-1].endswith('.json'):
            last = parts[-1][:-5]
            if parts[0] == 'comments' and len(parts) == 2:
                return self.send_json(localize_media(load('comments-thread.json'), self.base()))
            is_listing = (len(parts) == 1 and last in SORTS) or (parts[0] == 'r' and len(parts) == 3 and last in SORTS) \
                or (parts[0] == 'user' and last == 'submitted')
            if is_listing:
                listing = load('listing-hot.json')
                if query.get('after'):
                    listing = second_page(listing)
                return self.send_json(localize_media(listing, self.base()))

        self.send_json({'message': 'Not Found', 'error': 404}, 404)

    def do_POST(self):
        length = int(self.headers.get('Content-Length') or 0)
        raw = self.rfile.read(length).decode() if length else ''
        form = {k: v[0] for k, v in parse_qs(raw).items()}
        redacted = {k: ('<redacted>' if k in ('code', 'refresh_token', 'token') else v) for k, v in form.items()}
        self.log_request_line(redacted)
        path = urlparse(self.path).path

        if path in ('/api/v1/access_token', '/api/v1/revoke_token'):
            auth = self.headers.get('Authorization', '')
            if not auth.startswith('Basic '):
                return self.send_json({'error': 'unauthorized_client'}, 401)
            client_id = base64.b64decode(auth[6:]).decode().split(':')[0]
            if not client_id:
                return self.send_json({'error': 'invalid_client'}, 401)
            if path == '/api/v1/revoke_token':
                return self.send_json({})
            grant = form.get('grant_type', '')
            if grant in ('https://oauth.reddit.com/grants/installed_client', 'client_credentials'):
                if grant.endswith('installed_client') and len(form.get('device_id', '')) < 20:
                    return self.send_json({'error': 'invalid_request'}, 400)
                return self.send_json({'access_token': 'mock-apponly', 'token_type': 'bearer', 'expires_in': 3600, 'scope': '*'})
            if grant == 'authorization_code':
                if form.get('code') == 'bad':
                    return self.send_json({'error': 'invalid_grant'}, 400)
                return self.send_json({'access_token': 'mock-user', 'refresh_token': 'mock-refresh', 'token_type': 'bearer', 'expires_in': 3600, 'scope': 'identity read vote save'})
            if grant == 'refresh_token':
                return self.send_json({'access_token': 'mock-user-refreshed', 'token_type': 'bearer', 'expires_in': 3600, 'scope': 'identity read vote save'})
            return self.send_json({'error': 'unsupported_grant_type'}, 400)

        if not self.bearer_ok():
            return self.send_json({'message': 'Unauthorized', 'error': 401}, 401)
        if path in ('/api/vote', '/api/save', '/api/unsave'):
            if self.headers.get('Authorization', '').lower() == 'bearer mock-apponly':
                return self.send_json({'message': 'Forbidden', 'error': 403}, 403)
            return self.send_json({})
        if path == '/api/morechildren':
            children = [c for c in form.get('children', '').split(',') if c]
            things = [{'kind': 't1', 'data': {'id': c, 'name': 't1_' + c, 'author': f'replier_{c}', 'body': f'Loaded reply {c}.',
                                              'parent_id': 't1_c001', 'link_id': form.get('link_id'), 'depth': 1, 'score': 5,
                                              'ups': 5, 'downs': 0, 'likes': None, 'created_utc': 1761594000, 'edited': False,
                                              'replies': ''}} for c in children]
            return self.send_json({'json': {'errors': [], 'data': {'things': things}}})
        self.send_json({'message': 'Not Found', 'error': 404}, 404)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--port', type=int, default=8765)
    args = parser.parse_args()
    server = ThreadingHTTPServer(('127.0.0.1', args.port), Handler)
    print(f'Mock Reddit on http://127.0.0.1:{args.port}/', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == '__main__':
    sys.exit(main())
