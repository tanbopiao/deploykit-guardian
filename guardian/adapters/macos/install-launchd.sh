#!/usr/bin/env bash
# install-launchd.sh — optional macOS launchd adapter for the guardian heartbeat.
#
# cron (guardian.sh heartbeat start) stays the default on macOS. Some macOS
# setups (third-party cron managers, hardened configurations) prefer launchd.
# This adapter installs/removes a LaunchAgent that runs the SAME one-shot
# command as the cron path, keeping the guardian core untouched.
#
# Usage:
#   install-launchd.sh install    # install LaunchAgent + enable (idempotent)
#   install-launchd.sh remove     # unload + delete LaunchAgent
#
# Design contract unchanged: outbound-only, read-only patrol, clean removal.
set -u

GUARDIAN_HOME="${GUARDIAN_HOME:-$HOME/.guardian}"
PLIST_ID="com.deploykit.guardian.heartbeat"
PLIST="$HOME/Library/LaunchAgents/$PLIST_ID.plist"
SELF="$GUARDIAN_HOME/guardian.sh"

die() { echo "install-launchd.sh: $*" >&2; exit 64; }

cmd_install() {
  [ -x "$SELF" ] || die "guardian not installed at $SELF — run 'guardian.sh heartbeat start' once first"
  mkdir -p "$HOME/Library/LaunchAgents"
  # idempotent: unload any previous copy before rewriting
  launchctl unload "$PLIST" >/dev/null 2>&1 || true
  cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$PLIST_ID</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$SELF</string>
    <string>heartbeat</string>
    <string>cron</string>
  </array>
  <key>StartInterval</key><integer>3600</integer>
  <key>RunAtLoad</key><false/>
  <key>StandardErrorPath</key><string>$GUARDIAN_HOME/launchd.err.log</string>
</dict>
</plist>
EOF
  launchctl load "$PLIST" >/dev/null
  # keep cron path free of our entry if this adapter is used instead
  (crontab -l 2>/dev/null | grep -vF "# guardian-heartbeat-cron"; crontab -l 2>/dev/null | grep -vF "guardian.sh heartbeat cron") | crontab - 2>/dev/null || true
  echo "heartbeat launchd agent installed ($PLIST_ID, hourly)"
}

cmd_remove() {
  launchctl unload "$PLIST" >/dev/null 2>&1 || true
  if [ -f "$PLIST" ]; then rm -f "$PLIST"; echo "launchd agent removed"; else echo "launchd agent was not installed"; fi
}

case "${1:-}" in
  install) cmd_install;;
  remove)  cmd_remove;;
  *) echo "usage: install-launchd.sh install|remove"; exit 64;;
esac
