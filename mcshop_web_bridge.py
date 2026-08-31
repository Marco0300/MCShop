#!/usr/bin/env python3
import json, secrets, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse

ROOT=Path(__file__).parent
QUEUE=[]; WAITING={}; RESULTS={}; SESSIONS={}

def json_bytes(x): return json.dumps(x,separators=(',',':')).encode()
class Handler(BaseHTTPRequestHandler):
    def log_message(self,*a): pass
    def send_json(self,x,code=200):
        b=json_bytes(x); self.send_response(code); self.send_header('Content-Type','application/json'); self.send_header('Content-Length',str(len(b))); self.end_headers(); self.wfile.write(b)
    def body(self):
        n=int(self.headers.get('Content-Length','0')); return json.loads(self.rfile.read(n) or b'{}')
    def do_GET(self):
        p=urlparse(self.path).path
        if p=='/api/poll':
            self.send_json(QUEUE.pop(0) if QUEUE else {'empty':True}); return
        if p=='/api/status': self.send_json({'ok':True,'queued':len(QUEUE),'pending':len(WAITING)}); return
        if p=='/' or p=='/index.html':
            b=(ROOT/'web_index.html').read_bytes(); self.send_response(200); self.send_header('Content-Type','text/html; charset=utf-8'); self.send_header('Content-Length',str(len(b))); self.end_headers(); self.wfile.write(b); return
        if p.startswith('/assets/items/'):
            rel=p[len('/assets/items/'):]
            assets=(ROOT/'web_assets'/'items').resolve(); target=(assets/rel).resolve()
            if target.is_relative_to(assets) and target.is_file() and target.suffix=='.png':
                b=target.read_bytes(); self.send_response(200); self.send_header('Content-Type','image/png'); self.send_header('Cache-Control','public, max-age=86400'); self.send_header('Content-Length',str(len(b))); self.end_headers(); self.wfile.write(b); return
            self.send_error(404); return
        self.send_error(404)
    def do_POST(self):
        p=urlparse(self.path).path
        if p=='/api/request':
            data=self.body(); token=data.get('token') or secrets.token_urlsafe(24); req=data.get('request',{}); rid=secrets.token_urlsafe(18); req['clientKey']=token; WAITING[rid]=time.time()+30; QUEUE.append({'id':rid,'request':req}); self.send_json({'id':rid,'token':token}); return
        if p=='/api/respond':
            data=self.body(); rid=data.get('id'); if_ok=rid in WAITING
            if if_ok: WAITING.pop(rid,None); RESULTS[rid]=data.get('response',{})
            self.send_json({'ok':if_ok}); return
        if p=='/api/result':
            data=self.body(); rid=data.get('id'); self.send_json({'ready':rid in RESULTS,'response':RESULTS.pop(rid,None)}); return
        self.send_error(404)

def main():
    host='0.0.0.0'; port=8091
    print(f'MCShop web bridge listening on http://{host}:{port}')
    ThreadingHTTPServer((host,port),Handler).serve_forever()
if __name__=='__main__': main()
