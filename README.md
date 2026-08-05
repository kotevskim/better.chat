# Better.Chat

A better Rocket.Chat web client — removes the little frustrations and adds the
missing bits. Built around two ideas: a **grid** of multiple chats at once, and
**keyboard-first** navigation — switch between chats, read, reply, react —
without touching the mouse. Plus many smaller features and improvements over the
native web client: threads, starred, files, search, and more.

Single HTML file + a tiny local Python proxy (the proxy serves the page and
forwards REST calls so the browser's CORS rules don't get in the way; the live
WebSocket goes straight to the server).

It installs as a Docker container. Use **Chrome or Firefox** — they resolve
`*.localhost` to your machine natively and treat it as a secure context
(login + clipboard need that). Safari doesn't.

**[Visit the demo](https://kotevskim.github.io/better.chat/)** to explore it
first — the whole client on canned data, so there is nothing to install and no
server to point it at.

## Install via Docker

Needs only Docker — no Python. The image is public, so no login is needed, and
your server hostname is passed at run time rather than baked into the image.

### The latest version

**Replace `your.rocketchat.host` in the commands below with your own RC server:**
```bash
docker run -d --name better-chat --restart unless-stopped \
  -p 127.0.0.1:9000:9000 -e BC_SERVER=your.rocketchat.host \
  ghcr.io/kotevskim/better.chat && sleep 1 && docker logs better-chat
```

The `docker logs` at the end prints the startup banner — or the reason the
container refused to start, e.g. when `BC_SERVER` was left as the placeholder
above (the proxy exits immediately rather than serve a client whose avatars
and attachments can never load).

Then open **http://chat.localhost:9000**. An image name with no tag means
`:latest`, which always points at the newest release.

The container always listens on 9000 internally — the `-p host:container`
mapping decides the URL, so pick any free host port:

| mapping                  | open                                          |
|--------------------------|-----------------------------------------------|
| `-p 127.0.0.1:9000:9000` | http://chat.localhost:9000                    |
| `-p 127.0.0.1:80:9000`   | http://chat.localhost (no port in the URL)    |

Keep the `127.0.0.1:` prefix — it publishes the port to your machine only,
so nothing is reachable from your network. `--restart unless-stopped` makes
it start with Docker and survive crashes.

Pulling a newer image never touches a running container, so an update is
pull + replace. This is also the command to re-run any time you want the
newest release:

```bash
docker pull ghcr.io/kotevskim/better.chat && \
docker rm -f better-chat 2>/dev/null; \
docker run -d --name better-chat --restart unless-stopped \
  -p 127.0.0.1:9000:9000 -e BC_SERVER=your.rocketchat.host \
  ghcr.io/kotevskim/better.chat && sleep 1 && docker logs better-chat
```

To pin a specific version instead, add its tag — `ghcr.io/kotevskim/better.chat:v22`.

### The edge version

The latest development build — **may break**. It runs happily alongside the
released container: different container name, different port, so neither
disturbs the other.

```bash
docker pull ghcr.io/kotevskim/better.chat:edge && \
docker rm -f better-chat-edge 2>/dev/null; \
docker run -d --name better-chat-edge --restart unless-stopped \
  -p 127.0.0.1:9999:9000 -e BC_SERVER=your.rocketchat.host \
  ghcr.io/kotevskim/better.chat:edge && sleep 1 && docker logs better-chat-edge
```

Then open **http://chat.localhost:9999**. Re-run the same command whenever you
want the newest edge build — `:edge` is rebuilt on every push to `main`.

Because `:9999` is a different origin from `:9000`, it keeps its own session,
layout, and theme, so you can try edge without disturbing your released copy.

### Managing the containers

```bash
docker ps --filter name=better-chat
```

`docker logs better-chat` (or `better-chat-edge`) shows the startup banner with
the server it's proxying to, plus any errors.

Remove the containers and the image:

```bash
docker rm -f better-chat better-chat-edge 2>/dev/null; docker rmi -f $(docker images -q ghcr.io/kotevskim/better.chat)
```

## Why is this client secure

- **Your password can't be sniffed — even on public Wi-Fi.** It is never sent as
  plaintext and never stored: the browser SHA-256-digests it and sends the digest
  over the direct `wss://` WebSocket to your server, a connection the browser
  itself TLS-verifies. An interceptor can't decrypt it or impersonate the server
  without a valid certificate for your domain.
- **The auth token can't be intercepted either.** REST calls go through the local
  proxy, which verifies the server's TLS certificate against trusted CAs
  (system bundle or `certifi`) — a man-in-the-middle posing as your server gets
  rejected, not your token.
- **The token is only ever sent to *your* server.** It travels in headers (never
  in URLs, so no log/history leakage), and the client refuses to attach it to
  any external URL — a crafted message attachment pointing elsewhere is fetched
  without credentials.
- **Nothing is exposed to your network.** The proxy is reachable from your
  machine only — the container publishes its port to `127.0.0.1` — and it
  forwards nothing but a whitelist of Rocket.Chat API paths.
- **No third parties.** A single HTML file with zero external scripts, CDNs,
  fonts, or analytics — your credentials and messages only ever flow between
  your browser and your Rocket.Chat server.
- **localStorage, honestly.** Your session ("keep me signed in"), layout, and
  theme live in your browser's localStorage, scoped to the `chat.localhost`
  origin on your machine. With the box ticked that includes the login token
  (never the password). In theory JavaScript on that origin could read it —
  in practice that requires an XSS hole (all server-supplied content is
  HTML-escaped before rendering) or someone with access to your local machine,
  at which point they have your browser sessions anyway. Leave the box unticked
  and the token lives in memory only, gone when the tab closes.

## Running locally for development

Work on a checkout of this repo without touching your installed copy — run the
proxy from the repo folder on a separate port (9001), pointed at whichever
server you develop against (needs `python3`, nothing else):

```bash
cd better.chat
python3 docker/proxy.py <your-server-hostname> 9001
```

Then open **http://chat.localhost:9001**. Edits to `index.html` apply on
browser refresh; `Ctrl+C` stops the proxy. A released container on port 9000
keeps running independently, and the two origins keep separate sessions.

Or build and run the Docker image from the checkout:

```bash
docker build -f docker/Dockerfile -t better-chat-dev . && docker run --rm -p 127.0.0.1:9001:9000 -e BC_SERVER=<your-server-hostname> better-chat-dev
```
