# Better.Chat

A grid cockpit for Rocket.Chat (`chat.sorsix.com`) — watch several chats at once,
keyboard-first, threads, starred, files, search, and more. Single HTML file + a
tiny local Python proxy (the proxy serves the page and forwards REST calls so the
browser's CORS rules don't get in the way; the live WebSocket goes straight to
the server).

## Install (one command)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/kotevskim/better.chat/main/setup.sh)"
```

Then open **http://chat.localhost:9000** (opens automatically after setup).

Use **Chrome or Firefox** — they resolve `*.localhost` to your machine natively
and treat it as a secure context (login + clipboard need that). Safari doesn't.

Requirements: macOS or Linux, `python3` (the script installs it if missing).

## What the script does

- Downloads `index.html` + `proxy.py` into `~/.better-chat/`
- Installs an always-on service (starts at login, auto-restarts):
  - macOS: LaunchAgent `com.sorsix.betterchat`
  - Linux: systemd user unit `better-chat`
- Adds `bc-*` commands to your `~/.zshrc` / `~/.bashrc`

## Commands

| command      | does                                        |
|--------------|---------------------------------------------|
| `bc-status`  | is the proxy running                         |
| `bc-start` / `bc-stop` / `bc-restart` | control the service |
| `bc-open`    | open http://chat.localhost:9000              |
| `bc-logs`    | tail the proxy log                           |
| `bc-update`  | pull the latest app + proxy and restart      |

## Notes

- The proxy binds `127.0.0.1` only — nothing is exposed to your network, and
  your auth token never leaves the machine (it's sent in headers, not URLs).
- Your session ("keep me signed in"), layout, and theme live in your browser's
  localStorage for the `chat.localhost:9000` origin.
- Uninstall: `bc-stop`, delete `~/.better-chat/`, remove the LaunchAgent/systemd
  unit and the `# >>> better.chat >>>` block from your shell rc file.
