#!/usr/bin/env python3
"""
Better.Chat local proxy.

Serves grid-client.html AND forwards REST calls (/api/*, /avatar/*, /emoji-custom/*)
to your Rocket.Chat server. This sidesteps the browser CORS block on cross-origin
REST (reactions use POST /api/v1/chat.react). The DDP WebSocket still connects
directly to wss://<server>/websocket — WebSockets aren't subject to CORS.

Run it from the folder that contains grid-client.html:

    python3 proxy.py                      # server defaults to chat.sorsix.com, port 8000
    python3 proxy.py chat.example.com 8080

Then open  http://localhost:8000/grid-client.html  and sign in as usual.
"""
import sys, ssl, urllib.request, urllib.error
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

SERVER = sys.argv[1] if len(sys.argv) > 1 else "chat.sorsix.com"
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 8000
PROXIED_PREFIXES = ("/api/", "/avatar/", "/emoji-custom/", "/file-upload/", "/file/")
FORWARD_HEADERS = ("Content-Type", "X-Auth-Token", "X-User-Id", "Authorization", "Accept")


class Handler(SimpleHTTPRequestHandler):
    def _proxy(self, method):
        url = "https://%s%s" % (SERVER, self.path)
        length = int(self.headers.get("Content-Length", 0) or 0)
        body = self.rfile.read(length) if length else None
        req = urllib.request.Request(url, data=body, method=method)
        for h in FORWARD_HEADERS:
            v = self.headers.get(h)
            if v:
                req.add_header(h, v)
        ctx = ssl.create_default_context()
        ctx.check_hostname = False        # tolerate internal/self-signed certs (local dev proxy to your own server)
        ctx.verify_mode = ssl.CERT_NONE
        try:
            with urllib.request.urlopen(req, context=ctx, timeout=25) as r:
                data = r.read()
                self.send_response(r.status)
                self.send_header("Content-Type", r.headers.get("Content-Type", "application/json"))
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
        except urllib.error.HTTPError as e:
            data = e.read()
            self.send_response(e.code)
            self.send_header("Content-Type", e.headers.get("Content-Type", "application/json"))
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        except Exception as e:
            msg = ('{"success":false,"error":"proxy: %s"}' % e).encode()
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(msg)

    def do_GET(self):
        if self.path.startswith(PROXIED_PREFIXES):
            return self._proxy("GET")
        return super().do_GET()

    def do_POST(self):
        if self.path.startswith(PROXIED_PREFIXES):
            return self._proxy("POST")
        self.send_response(404)
        self.end_headers()

    def log_message(self, *a):
        pass


if __name__ == "__main__":
    print("Better.Chat proxy → https://%s   serving http://localhost:%d/grid-client.html" % (SERVER, PORT))
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
