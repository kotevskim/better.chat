# Better.Chat

A grid cockpit for any Rocket.Chat server — watch several chats at once,
keyboard-first, threads, starred, files, search, and more. Single HTML file + a
tiny local Python proxy (the proxy serves the page and forwards REST calls so the
browser's CORS rules don't get in the way; the live WebSocket goes straight to
the server).

## Install (one command)

```bash
bash -c "$(curl -fsSL "https://raw.githubusercontent.com/kotevskim/better.chat/main/setup.sh?ts=$(date +%s)")"
```

The script asks for your Rocket.Chat server hostname once (stored only in
`~/.better-chat/server`, never in this repo). Then open
**http://chat.localhost:9000** (opens automatically after setup).

> Re-running the command is safe — it's also how you pick up new or updated
> `bc-*` commands. After it finishes, run `source ~/.zshrc` (Linux: `~/.bashrc`)
> or open a new terminal; your current shell keeps the old commands until then.

Use **Chrome or Firefox** — they resolve `*.localhost` to your machine natively
and treat it as a secure context (login + clipboard need that). Safari doesn't.

Requirements: macOS or Linux, `python3` (the script installs it if missing).

## What the script does

- Downloads `index.html` + `proxy.py` (the newest released version) into `~/.better-chat/`
- Installs an always-on service (starts at login, auto-restarts):
  - macOS: LaunchAgent `com.betterchat`
  - Linux: systemd user unit `better-chat`
- Adds `bc-*` commands to your `~/.zshrc` / `~/.bashrc`

## Commands

| command      | does                                        |
|--------------|---------------------------------------------|
| `bc-status`  | is the proxy running                         |
| `bc-start` / `bc-stop` / `bc-restart` | control the service |
| `bc-open`    | open http://chat.localhost:9000              |
| `bc-logs`    | tail the proxy log                           |
| `bc-version` | which version is installed                   |
| `bc-versions` | list all released versions with their notes links, marking the installed one |
| `bc-update`  | update to the newest released version         |
| `bc-update v14` | pin to a specific release (or any branch/commit) |
| `bc-update edge` | latest development build — may break      |

`bc-update` with no argument always jumps to the newest published release, even if
you previously pinned an older one.

## Running locally for development

Work on a checkout of this repo without touching your installed copy — run the
proxy from the repo folder on a separate port (9001), pointed at whichever
server you develop against:

```bash
cd better.chat
python3 proxy.py <your-server-hostname> 9001
```

Then open **http://chat.localhost:9001**. Edits to `index.html` apply on
browser refresh; `Ctrl+C` stops the proxy. The installed service on port 9000
keeps running independently, and the two origins keep separate sessions.

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
- **Nothing is exposed to your network.** The proxy binds `127.0.0.1` only and
  forwards nothing but a whitelist of Rocket.Chat API paths.
- **No third parties.** A single HTML file with zero external scripts, CDNs,
  fonts, or analytics — your credentials and messages only ever flow between
  your browser and your Rocket.Chat server.
- **localStorage, honestly.** With "keep me signed in" ticked, the login token
  (never the password) is kept in localStorage, scoped to the `chat.localhost`
  origin on your machine. In theory JavaScript on that origin could read it —
  in practice that requires an XSS hole (all server-supplied content is
  HTML-escaped before rendering) or someone with access to your local machine,
  at which point they have your browser sessions anyway. Leave the box unticked
  and the token lives in memory only, gone when the tab closes.

## Notes

- The proxy binds `127.0.0.1` only — nothing is exposed to your network, and
  your auth token never leaves the machine (it's sent in headers, not URLs).
- Your session ("keep me signed in"), layout, and theme live in your browser's
  localStorage for the `chat.localhost:9000` origin.

## Uninstall

**macOS** — stop the service, remove all files, and drop the `bc-*` commands:

```bash
launchctl bootout gui/$(id -u)/com.betterchat 2>/dev/null; rm -f ~/Library/LaunchAgents/com.betterchat.plist; rm -rf ~/.better-chat; sed -i '' '/# >>> better.chat >>>/,/# <<< better.chat <<</d' ~/.zshrc
```

Then open a **new terminal** and verify everything is gone (all three should be empty/0):

```bash
launchctl list | grep -i better; ls ~/.better-chat 2>/dev/null; grep -c better.chat ~/.zshrc
```

**Linux** — same idea with systemd:

```bash
systemctl --user disable --now better-chat 2>/dev/null; rm -f ~/.config/systemd/user/better-chat.service; systemctl --user daemon-reload; rm -rf ~/.better-chat; sed -i '/# >>> better.chat >>>/,/# <<< better.chat <<</d' ~/.bashrc
```

Uninstalling doesn't touch your browser's localStorage — the saved session/layout
for `chat.localhost:9000` survives a reinstall.
