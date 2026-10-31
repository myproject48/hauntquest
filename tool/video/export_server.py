#!/usr/bin/env python3
"""Receive opt-in Android test-frame exports over a localhost-only adb tunnel."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json
import re

ROOT=Path(__file__).resolve().parents[2]/'build/video/android'
ROOT.mkdir(parents=True,exist_ok=True)
class Receiver(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path=='/manifest.json':
            relative='manifest.json'
        elif re.fullmatch(r'/[a-z_]+/[0-9]{6}\.png',self.path):
            relative=self.path[1:]
        else:
            self.send_error(400);return
        length=int(self.headers.get('Content-Length','0'))
        if length<1 or length>8_000_000:
            self.send_error(400);return
        data=self.rfile.read(length)
        if len(data)!=length:
            self.send_error(400);return
        if relative=='manifest.json':json.loads(data)
        target=ROOT/relative
        target.parent.mkdir(parents=True,exist_ok=True)
        temporary=target.with_suffix('.tmp')
        temporary.write_bytes(data)
        temporary.replace(target)
        self.send_response(201);self.end_headers();self.wfile.write(b'OK')
    def log_message(self,*args):pass
print('Frame export bound to localhost:8765',flush=True)
ThreadingHTTPServer(('127.0.0.1',8765),Receiver).serve_forever()
