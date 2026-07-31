#!/usr/bin/env bash
# Better.Chat setup — installs the app + always-on local proxy and bc-* shell commands.
#
# One-liner install:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/kotevskim/better.chat/main/setup.sh)"
#
# After install:  open http://chat.localhost:9000  (Chrome/Firefox — no /etc/hosts needed)
set -euo pipefail

REPO="kotevskim/better.chat"
REPO_RAW_BASE="https://raw.githubusercontent.com/$REPO"
REPO_RAW="$REPO_RAW_BASE/main"          # installer itself always pulls from main
EDGE_BRANCH="main"                       # what `bc-update edge` tracks (latest pushed code, not a release)
DIR="$HOME/.better-chat"
PORT=9000
URL="http://chat.localhost:$PORT"
LABEL="com.betterchat"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
UNIT_DIR="$HOME/.config/systemd/user"
UNIT="$UNIT_DIR/better-chat.service"

say()  { printf "\033[1;34m▸ %s\033[0m\n" "$*"; }
fail() { printf "\033[1;31m✖ %s\033[0m\n" "$*"; exit 1; }

OS="$(uname -s)"

# ---------- 0. which Rocket.Chat server? (not hardcoded anywhere) ----------
RC_SERVER="${BC_SERVER:-}"                                   # non-interactive: BC_SERVER=chat.example.com bash setup.sh
if [ -z "$RC_SERVER" ] && [ -f "$DIR/server" ]; then RC_SERVER="$(cat "$DIR/server")"; fi   # keep existing choice on re-run
if [ -z "$RC_SERVER" ]; then
  read -rp "Rocket.Chat server hostname (e.g. chat.example.com): " RC_SERVER
fi
RC_SERVER="$(printf '%s' "$RC_SERVER" | sed -e 's#^https\?://##' -e 's#/$##' | tr -d '[:space:]')"
[ -n "$RC_SERVER" ] || fail "A server hostname is required."

# ---------- 1. python3 ----------
if ! command -v python3 >/dev/null 2>&1; then
  say "python3 not found — installing…"
  if [ "$OS" = "Darwin" ]; then
    if command -v brew >/dev/null 2>&1; then
      brew install python3
    else
      say "Triggering Xcode Command Line Tools install (includes python3). Re-run this script when it finishes."
      xcode-select --install || true
      exit 1
    fi
  else
    if command -v apt-get >/dev/null 2>&1; then sudo apt-get update -qq && sudo apt-get install -y python3
    elif command -v dnf >/dev/null 2>&1; then sudo dnf install -y python3
    elif command -v pacman >/dev/null 2>&1; then sudo pacman -S --noconfirm python
    else fail "No known package manager found — install python3 manually, then re-run."
    fi
  fi
fi
command -v python3 >/dev/null 2>&1 || fail "python3 still not available."

# ---------- 2. files ----------
say "Installing files to $DIR"
mkdir -p "$DIR"
TS=$(date +%s)   # cache-bust the raw CDN (~5 min TTL) so a fresh push installs fresh files
curl -fsSL "$REPO_RAW/index.html?ts=$TS" -o "$DIR/index.html" || fail "Couldn't download index.html"
curl -fsSL "$REPO_RAW/proxy.py?ts=$TS"   -o "$DIR/proxy.py"   || fail "Couldn't download proxy.py"
printf '%s\n' "$RC_SERVER" > "$DIR/server"   # the proxy reads its target from here (kept out of the public repo)
printf '%s\n' "main" > "$DIR/ref"          # which git ref the installed files came from

PY="$(command -v python3)"

# ---------- 3. always-on service (starts at login, auto-restarts) ----------
if [ "$OS" = "Darwin" ]; then
  say "Installing LaunchAgent $LABEL"
  # bootout any previous incarnation (incl. the old label) — `unload` chokes with EIO on stale jobs
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  launchctl bootout "gui/$(id -u)/com.sorsix.betterchat" 2>/dev/null || true
  rm -f "$HOME/Library/LaunchAgents/com.sorsix.betterchat.plist"
  mkdir -p "$HOME/Library/LaunchAgents"
  cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array>
    <string>$PY</string><string>-u</string><string>$DIR/proxy.py</string><string>$RC_SERVER</string><string>$PORT</string>
  </array>
  <key>WorkingDirectory</key><string>$DIR</string>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>$DIR/proxy.log</string>
  <key>StandardErrorPath</key><string>$DIR/proxy.log</string>
</dict></plist>
EOF
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
else
  say "Installing systemd user service better-chat"
  mkdir -p "$UNIT_DIR"
  cat > "$UNIT" <<EOF
[Unit]
Description=Better.Chat local proxy

[Service]
ExecStart=$PY $DIR/proxy.py $RC_SERVER $PORT
WorkingDirectory=$DIR
Restart=always
RestartSec=2
StandardOutput=append:$DIR/proxy.log
StandardError=append:$DIR/proxy.log

[Install]
WantedBy=default.target
EOF
  systemctl --user daemon-reload
  systemctl --user enable --now better-chat
fi

# ---------- 4. bc-* shell commands ----------
case "$(basename "${SHELL:-bash}")" in
  zsh)  RC_FILE="$HOME/.zshrc" ;;
  bash) RC_FILE="$HOME/.bashrc" ;;
  *)    RC_FILE="" ;;
esac

MARK_BEGIN="# >>> better.chat >>>"
MARK_END="# <<< better.chat <<<"
if [ -n "$RC_FILE" ]; then
  say "Adding bc-* commands to $RC_FILE"
  touch "$RC_FILE"
  # remove a previous block so re-running stays idempotent
  if grep -q "$MARK_BEGIN" "$RC_FILE"; then
    sed -i.bak "/$MARK_BEGIN/,/$MARK_END/d" "$RC_FILE"
  fi
  if [ "$OS" = "Darwin" ]; then
    cat >> "$RC_FILE" <<EOF
$MARK_BEGIN
bc-start()   { launchctl list 2>/dev/null | grep -q "$LABEL" && echo "better.chat: already running" || launchctl bootstrap "gui/\$(id -u)" "$PLIST"; }
bc-stop()    { launchctl bootout "gui/\$(id -u)/$LABEL" 2>/dev/null && echo "better.chat: stopped" || echo "better.chat: not running"; }
bc-restart() { launchctl bootout "gui/\$(id -u)/$LABEL" 2>/dev/null; launchctl bootstrap "gui/\$(id -u)" "$PLIST"; }
bc-status()  { launchctl list | grep -q $LABEL && echo "better.chat: running \$(bc-version) ($URL)" || echo "better.chat: stopped (\$(bc-version))"; }
bc-logs()    { tail -f "$DIR/proxy.log"; }
bc-open()    { open "$URL"; }
bc-version() { cat "$DIR/ref" 2>/dev/null || echo "unknown"; }
bc-versions() {   # every released version + its notes, newest first; marks the installed one
  local cur tags t
  cur=\$(bc-version)
  tags=\$(curl -fsSL "https://api.github.com/repos/$REPO/releases?per_page=100" 2>/dev/null | sed -n 's/.*"tag_name": *"\\([^"]*\\)".*/\\1/p')
  [ -z "\$tags" ] && tags=\$(curl -fsSL "https://api.github.com/repos/$REPO/tags?per_page=100" 2>/dev/null | sed -n 's/.*"name": *"\\([^"]*\\)".*/\\1/p')
  [ -z "\$tags" ] && { echo "better.chat: couldn't fetch versions from GitHub"; return 1; }
  echo "\$tags" | while IFS= read -r t; do   # line-by-line: works in zsh (no word-split) and bash alike
    printf '%-8s %s%s\\n' "\$t" "https://github.com/$REPO/releases/tag/\$t" "\$([ "\$t" = "\$cur" ] && printf '  (installed)')"
  done
}
bc-update()  {
  local want="\$1" ref ts=\$(date +%s)
  if [ -z "\$want" ]; then                                   # newest published tag, with graceful fallbacks
    ref=\$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null | sed -n 's/.*"tag_name": *"\\([^"]*\\)".*/\\1/p' | head -1)
    [ -z "\$ref" ] && ref=\$(curl -fsSL "https://api.github.com/repos/$REPO/tags" 2>/dev/null | sed -n 's/.*"name": *"\\([^"]*\\)".*/\\1/p' | head -1)
    [ -z "\$ref" ] && { ref="main"; echo "better.chat: couldn't resolve the latest tag — falling back to main"; }
  elif [ "\$want" = "edge" ]; then ref="$EDGE_BRANCH"        # latest development build, may break
  else ref="\$want"; fi                                      # a tag, branch or commit SHA
  curl -fsSL "$REPO_RAW_BASE/\$ref/index.html?ts=\$ts" -o "$DIR/index.html.new" &&
  curl -fsSL "$REPO_RAW_BASE/\$ref/proxy.py?ts=\$ts"   -o "$DIR/proxy.py.new"  || { rm -f "$DIR"/*.new; echo "better.chat: couldn't fetch '\$ref' — no such tag or branch (nothing changed)"; return 1; }
  mv "$DIR/index.html.new" "$DIR/index.html"; mv "$DIR/proxy.py.new" "$DIR/proxy.py"
  printf '%s\\n' "\$ref" > "$DIR/ref"
  bc-restart && echo "better.chat updated → \$ref"
}   # ?ts busts the raw CDN cache (~5 min TTL)
$MARK_END
EOF
  else
    cat >> "$RC_FILE" <<EOF
$MARK_BEGIN
bc-start()   { systemctl --user start better-chat; }
bc-stop()    { systemctl --user stop better-chat; }
bc-restart() { systemctl --user restart better-chat; }
bc-status()  { systemctl --user is-active better-chat >/dev/null && echo "better.chat: running \$(bc-version) ($URL)" || echo "better.chat: stopped (\$(bc-version))"; }
bc-logs()    { tail -f "$DIR/proxy.log"; }
bc-open()    { xdg-open "$URL" >/dev/null 2>&1 & }
bc-version() { cat "$DIR/ref" 2>/dev/null || echo "unknown"; }
bc-versions() {   # every released version + its notes, newest first; marks the installed one
  local cur tags t
  cur=\$(bc-version)
  tags=\$(curl -fsSL "https://api.github.com/repos/$REPO/releases?per_page=100" 2>/dev/null | sed -n 's/.*"tag_name": *"\\([^"]*\\)".*/\\1/p')
  [ -z "\$tags" ] && tags=\$(curl -fsSL "https://api.github.com/repos/$REPO/tags?per_page=100" 2>/dev/null | sed -n 's/.*"name": *"\\([^"]*\\)".*/\\1/p')
  [ -z "\$tags" ] && { echo "better.chat: couldn't fetch versions from GitHub"; return 1; }
  echo "\$tags" | while IFS= read -r t; do   # line-by-line: works in zsh (no word-split) and bash alike
    printf '%-8s %s%s\\n' "\$t" "https://github.com/$REPO/releases/tag/\$t" "\$([ "\$t" = "\$cur" ] && printf '  (installed)')"
  done
}
bc-update()  {
  local want="\$1" ref ts=\$(date +%s)
  if [ -z "\$want" ]; then                                   # newest published tag, with graceful fallbacks
    ref=\$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null | sed -n 's/.*"tag_name": *"\\([^"]*\\)".*/\\1/p' | head -1)
    [ -z "\$ref" ] && ref=\$(curl -fsSL "https://api.github.com/repos/$REPO/tags" 2>/dev/null | sed -n 's/.*"name": *"\\([^"]*\\)".*/\\1/p' | head -1)
    [ -z "\$ref" ] && { ref="main"; echo "better.chat: couldn't resolve the latest tag — falling back to main"; }
  elif [ "\$want" = "edge" ]; then ref="$EDGE_BRANCH"        # latest development build, may break
  else ref="\$want"; fi                                      # a tag, branch or commit SHA
  curl -fsSL "$REPO_RAW_BASE/\$ref/index.html?ts=\$ts" -o "$DIR/index.html.new" &&
  curl -fsSL "$REPO_RAW_BASE/\$ref/proxy.py?ts=\$ts"   -o "$DIR/proxy.py.new"  || { rm -f "$DIR"/*.new; echo "better.chat: couldn't fetch '\$ref' — no such tag or branch (nothing changed)"; return 1; }
  mv "$DIR/index.html.new" "$DIR/index.html"; mv "$DIR/proxy.py.new" "$DIR/proxy.py"
  printf '%s\\n' "\$ref" > "$DIR/ref"
  bc-restart && echo "better.chat updated → \$ref"
}   # ?ts busts the raw CDN cache (~5 min TTL)
$MARK_END
EOF
  fi
else
  say "Unknown shell '$SHELL' — add the bc-* helpers manually (see README)."
fi

# ---------- 5. done ----------
sleep 1
if curl -fsS -o /dev/null "http://127.0.0.1:$PORT/"; then
  say "Better.Chat is running → $URL"
  if [ "$OS" = "Darwin" ]; then open "$URL"; else xdg-open "$URL" >/dev/null 2>&1 || true; fi
  say "Open a NEW terminal (or 'source $RC_FILE') to use: bc-start bc-stop bc-restart bc-status bc-version bc-versions bc-logs bc-open bc-update [v17|edge]"
else
  fail "Proxy didn't answer on port $PORT — check $DIR/proxy.log"
fi
