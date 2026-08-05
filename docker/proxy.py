#!/usr/bin/env python3
"""
Better.Chat local proxy.

Serves the app (index.html at "/") AND forwards REST calls (/api/*, /avatar/*,
/emoji-custom/*, /file-upload/*, /file/*) to your Rocket.Chat server. This
sidesteps the browser CORS block on cross-origin REST. The DDP WebSocket still
connects directly to wss://<server>/websocket — WebSockets aren't subject to CORS.

index.html is found next to this script, or one directory up (a repo checkout,
where this file lives in docker/):

    python3 docker/proxy.py chat.example.com        # port defaults to 9000
    python3 docker/proxy.py chat.example.com 8080

The server can also come from the BC_SERVER env var. Then open
http://chat.localhost:9000.

Env overrides (used by the Docker image): BC_PORT sets the port when no argv
port is given; BC_BIND sets the bind address (default 127.0.0.1 — inside a
container it must be 0.0.0.0, with `docker run -p 127.0.0.1:<port>:9000`
restoring the loopback-only guarantee on the host).
"""
import os, sys, ssl, urllib.request, urllib.error
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

def _server():
    if len(sys.argv) > 1 and sys.argv[1].strip():
        return sys.argv[1].strip()
    if os.environ.get("BC_SERVER", "").strip():
        return os.environ["BC_SERVER"].strip()
    sys.exit("No Rocket.Chat server configured. Run: python3 docker/proxy.py <server-hostname>  (or set BC_SERVER)")

SERVER = _server()

# A wrong hostname here is close to invisible: the browser talks to Rocket.Chat directly over the
# websocket, so login and messages work normally and only the routes that go through this proxy
# (avatars, custom emoji, file attachments) fail. Say so at startup instead of leaving it to be
# discovered as "images don't load".
PLACEHOLDER_HOSTS = {
    "your.rocketchat.host", "your-rocketchat-server.com", "your.rocketchat-server.com",
    "your.server.com", "<your-server-hostname>", "your-server-hostname",
}
if SERVER.lower().strip("<>") in PLACEHOLDER_HOSTS or SERVER.lower() in PLACEHOLDER_HOSTS:
    sys.exit("Refusing to start: the server is still the documentation placeholder %r.\n"
             "Pass your own Rocket.Chat hostname, e.g. -e BC_SERVER=chat.example.com" % SERVER)

def _warn_unresolvable():
    import socket
    try:
        socket.getaddrinfo(SERVER, 443)
    except OSError as e:
        print("WARNING: %s does not resolve from here (%s).\n"
              "         Chats will still work — the browser reaches Rocket.Chat directly — but avatars,\n"
              "         custom emoji and file attachments are proxied through here and will fail." % (SERVER, e))

PORT = int(sys.argv[2]) if len(sys.argv) > 2 else int(os.environ.get("BC_PORT", "").strip() or 9000)
BIND = os.environ.get("BC_BIND", "").strip() or "127.0.0.1"

def _ssl_ctx():
    """Verifying TLS context. python.org builds on macOS often ship without a CA
    bundle — fall back to certifi, then the macOS system bundle."""
    try:
        import certifi
        return ssl.create_default_context(cafile=certifi.where())
    except ImportError:
        pass
    if ssl.get_default_verify_paths().cafile is None and os.path.exists("/etc/ssl/cert.pem"):
        return ssl.create_default_context(cafile="/etc/ssl/cert.pem")
    return ssl.create_default_context()

CTX = _ssl_ctx()
def _html_path():
    """index.html sits next to this script in the image (/app), but one directory
    up in a repo checkout (this file lives in docker/)."""
    here = os.path.dirname(os.path.abspath(__file__))
    for d in (here, os.path.dirname(here)):
        p = os.path.join(d, "index.html")
        if os.path.exists(p):
            return p
    return os.path.join(here, "index.html")   # let the 500 name the expected place

HTML_PATH = _html_path()
PROXIED_PREFIXES = ("/api/", "/avatar/", "/emoji-custom/", "/file-upload/", "/file/")
# User-Agent is forwarded so WAFs (e.g. Cloudflare) see the real browser, not "Python-urllib" — which they block with 403
FORWARD_HEADERS = ("Content-Type", "X-Auth-Token", "X-User-Id", "Authorization", "Accept", "User-Agent")


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
        try:
            with urllib.request.urlopen(req, context=CTX, timeout=25) as r:
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
            hint = " (TLS trust problem: pip3 install certifi, then restart the proxy)" if isinstance(e, (ssl.SSLError, urllib.error.URLError)) and "CERTIFICATE_VERIFY" in str(e) else ""
            msg = ('{"success":false,"error":"proxy: %s%s"}' % (e, hint)).encode()
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(msg)

    def _serve_app(self):
        try:
            with open(HTML_PATH, "rb") as f:
                data = f.read()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        except OSError:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(("index.html not found at " + HTML_PATH).encode())

    def do_GET(self):
        if self.path.startswith(PROXIED_PREFIXES):
            return self._proxy("GET")
        return self._serve_app()          # any non-proxied path serves the app (no filename in the URL)

    def do_POST(self):
        if self.path.startswith(PROXIED_PREFIXES):
            return self._proxy("POST")
        self.send_response(404)
        self.end_headers()

    def log_message(self, *a):
        pass


class Server(ThreadingHTTPServer):
    def handle_error(self, request, client_address):
        t = sys.exc_info()[0]
        if t and issubclass(t, (BrokenPipeError, ConnectionResetError)):
            return   # the browser closed the connection mid-response — not interesting
        super().handle_error(request, client_address)


if __name__ == "__main__":
    if BIND == "127.0.0.1":
        where = "serving http://chat.localhost:%d" % PORT
    else:
        # In a container the host-side port mapping is invisible from in here, so
        # naming a chat.localhost URL would be a guess — and a wrong one for any
        # mapping that doesn't reuse the container's own port.
        where = "listening on %s:%d — open the host port mapped to it (docker run -p 127.0.0.1:<port>:%d)" % (BIND, PORT, PORT)
    print("Better.Chat proxy → https://%s   %s" % (SERVER, where))
    _warn_unresolvable()   # after the banner, so the warning is the last thing on screen
    Server((BIND, PORT), Handler).serve_forever()
