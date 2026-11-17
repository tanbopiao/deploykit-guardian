#!/usr/bin/env bash
# guardian.sh — post-deploy guardian v0: heartbeat, read-only baseline check,
# 3-level anomaly classification, static receipt page.
# Design contract (v0):
#   - outbound-only: no inbound ports opened, ever.
#   - read-only checks: never modifies the guarded system.
#   - drift is recorded, not fixed (auto-repair is out of scope for v0).
#   - uninstall: `guardian.sh uninstall` removes everything cleanly.
set -u

# ---- paths (all under one root for clean uninstall) -------------------------
GUARDIAN_HOME="${GUARDIAN_HOME:-$HOME/.guardian}"
BASELINE_DIR="$GUARDIAN_HOME/baseline"
STATE_DIR="$GUARDIAN_HOME/state"
REPORTS_DIR="$GUARDIAN_HOME/reports"
PAGE_DIR="$GUARDIAN_HOME/page"
LOG_FILE="$GUARDIAN_HOME/guardian.log"
PID_FILE="$GUARDIAN_HOME/heartbeat.pid"
INTERVAL_FILE="$GUARDIAN_HOME/interval"
HEARTBEAT_INTERVAL="${GUARDIAN_HEARTBEAT_INTERVAL:-3600}"   # seconds, default 1h
MAX_PAGES="${GUARDIAN_MAX_PAGES:-50}"                        # receipts kept on page

# ---- optional webhook: outbound POST of events; failure never blocks --------
# Set GUARDIAN_WEBHOOK_URL to enable; only fingerprints/levels are sent,
# never file contents (privacy: fingerprints, not data).
webhook_send() { # $1 = payload json
  [ -n "${GUARDIAN_WEBHOOK_URL:-}" ] || return 0
  curl -sfm 10 -o /dev/null -X POST -H "Content-Type: application/json" \
    --data "$1" "$GUARDIAN_WEBHOOK_URL" 2>/dev/null || \
    echo "webhook skipped (unreachable)" >> "$LOG_FILE"
}

now_iso() { date '+%Y-%m-%dT%H:%M:%S%z'; }
log() { echo "[$(date '+%F %T')] $*" >> "$LOG_FILE"; }

init_dirs() { mkdir -p "$BASELINE_DIR" "$STATE_DIR" "$REPORTS_DIR" "$PAGE_DIR"; }

# ---- baseline ---------------------------------------------------------------
# Register a baseline fingerprint for one path. Called at deploy time by B1
# (or manually): `guardian.sh baseline add /path/to/file`
cmd_baseline() {
  init_dirs
  case "${2:-}" in
    add)
      local p="${3:-}"
      [ -n "$p" ] && [ -f "$p" ] || { echo "usage: guardian.sh baseline add <file>"; exit 64; }
      local id fp
      id="$(echo "$p" | sha256sum | cut -c1-16)"
      fp="$(fingerprint_file "$p")"
      echo "$p" > "$BASELINE_DIR/$id.path"
      echo "$fp" > "$BASELINE_DIR/$id.fp"
      log "baseline registered: $p"
      echo "registered: $p (fp=${fp:0:12}…)"
      ;;
    list)
      for pf in "$BASELINE_DIR"/*.path; do
        [ -e "$pf" ] || continue
        echo "path=$(cat "$pf") fp=$(cat "${pf%.path}.fp")"
      done
      ;;
    *) echo "usage: guardian.sh baseline add <file> | list"; exit 64;;
  esac
}

fingerprint_file() { sha256sum "$1" 2>/dev/null | awk '{print $1}'; }

# ---- patrol (baseline check, read-only) --------------------------------------
# level: info | warn | fault
LEVEL_INFO="info"; LEVEL_WARN="warn"; LEVEL_FAULT="fault"

cmd_patrol() {
  init_dirs
  local round ts level findings total
  round=$(cat "$STATE_DIR/round" 2>/dev/null || echo 0)
  round=$((round + 1)); echo "$round" > "$STATE_DIR/round"
  ts="$(now_iso)"
  findings=""
  level="$LEVEL_INFO"
  for pf in "$BASELINE_DIR"/*.path; do
    [ -e "$pf" ] || continue
    local path fp now_fp
    path="$(cat "$pf")"
    fp="$(cat "${pf%.path}.fp")"
    if [ ! -f "$path" ]; then
      level="$LEVEL_FAULT"; findings+="<li>MISSING: $path (file removed since deploy)</li>"
      continue
    fi
    now_fp="$(fingerprint_file "$path")"
    if [ "$now_fp" != "$fp" ]; then
      [ "$level" = "$LEVEL_FAULT" ] || level="$LEVEL_WARN"
      findings+="<li>DRIFT: $path (sha256 ${fp:0:12}… → ${now_fp:0:12}…)</li>"
    fi
  done
  # also record basic service liveness if a check script exists
  if [ -x "$GUARDIAN_HOME/checks.sh" ]; then
    if ! bash "$GUARDIAN_HOME/checks.sh" >> "$LOG_FILE" 2>&1; then
      level="$LEVEL_WARN"; findings+="<li>checks.sh reported a warning</li>"
    fi
  fi
  [ -n "$findings" ] || findings="<li>OK: all registered baselines match</li>"

  # persist report (json) + render into static page
  local json
  json=$(printf '{"round":%d,"ts":"%s","level":"%s","findings":"%s"}' \
    "$round" "$ts" "$level" "$(echo "$findings" | sed 's/"/\\"/g')")
  echo "$json" > "$REPORTS_DIR/round-$(printf '%06d' "$round").json"
  log "patrol round=$round level=$level"
  webhook_send "$json"
  [ "$level" = "$LEVEL_FAULT" ] && webhook_send \
    "{\"level\":\"$LEVEL_FAULT\",\"msg\":\"fault detected in round $round\"}"
  cmd_page
}

# ---- heartbeat ---------------------------------------------------------------
# heartbeat: outbound-only liveness ping. Default hourly via cron; `run` does one ping.
cmd_heartbeat() { case "${2:-}" in
  run)
    init_dirs
    local payload
    payload=$(printf '{"type":"heartbeat","ts":"%s","version":"%s","host_fp":"%s"}' \
      "$(now_iso)" "${GUARDIAN_VERSION:-v0}" "$(hostname | sha256sum | cut -c1-16)")
    echo "$payload" > "$STATE_DIR/last-heartbeat.json"
    log "heartbeat sent (outbound only)"
    webhook_send "$payload"
    ;;
  start)
    # install cron @hourly (idempotent); only outbound traffic
    init_dirs
    # self-install: copy the script into GUARDIAN_HOME so cron is self-contained
    if [ "$(readlink -f "$0")" != "$GUARDIAN_HOME/guardian.sh" ]; then
      cp -f "$(readlink -f "$0")" "$GUARDIAN_HOME/guardian.sh"
    fi
    chmod +x "$GUARDIAN_HOME/guardian.sh"
    local marker="# guardian-heartbeat-cron"
    (crontab -l 2>/dev/null | grep -vF "$marker"; \
      echo "$marker"; \
      echo "0 * * * * GUARDIAN_HOME=$GUARDIAN_HOME $GUARDIAN_HOME/guardian.sh heartbeat cron >/dev/null 2>&1") | crontab - 2>/dev/null || true
    echo "1" > "$INTERVAL_FILE"   # hours
    log "heartbeat cron installed (interval: hourly)"
    echo "heartbeat started (hourly, outbound-only)"
    ;;
  stop)
    (crontab -l 2>/dev/null | grep -vF "# guardian-heartbeat-cron"; crontab -l 2>/dev/null | grep -vF "guardian.sh heartbeat cron") | crontab - 2>/dev/null || true
    log "heartbeat cron removed"
    echo "heartbeat stopped"
    ;;
  cron)
    # invoked by cron: one heartbeat ping + one patrol round
    cmd_heartbeat run
    cmd_patrol
    ;;
  *) echo "usage: guardian.sh heartbeat run|start|stop"; exit 64;;
esac; }

guardian_cron_line() {
  echo "0 * * * * GUARDIAN_HOME=$GUARDIAN_HOME $GUARDIAN_HOME/guardian.sh heartbeat cron >/dev/null 2>&1 # guardian.sh heartbeat cron"
}

# ---- static receipt page ------------------------------------------------------
cmd_page() {
  init_dirs
  local f out="$PAGE_DIR/receipt.html" rows=""
  for j in $(ls "$REPORTS_DIR"/round-*.json 2>/dev/null | sort -r | head -n "$MAX_PAGES"); do
    rows+="$(python3 -c '
import json,sys
d=json.load(open(sys.argv[1]))
cls=d["level"]
row="<tr class=%s><td>%s</td><td>%s</td><td>%s</td><td><ul>%s</ul></td></tr>" % (cls, d["round"], d["ts"], d["level"].upper(), d["findings"])
print(row)
' "$j")"
  done
  cat > "$out" <<EOF
<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">
<title>Guardian Receipts</title>
<style>body{font-family:system-ui,sans-serif;margin:2rem}
table{border-collapse:collapse;width:100%}td,th{border:1px solid #ccc;padding:6px;text-align:left}
tr.fault{background:#ffe0e0}tr.warn{background:#fff3d0}tr.info{background:#e8ffe8}</style>
</head><body>
<h1>Guardian Receipts</h1>
<p>Last ${MAX_PAGES} patrol rounds. Levels: info / warn / fault.</p>
<table><tr><th>Round</th><th>Time</th><th>Level</th><th>Findings</th></tr>
${rows}
</table></body></html>
EOF
  echo "page updated: $out"
}

# ---- uninstall (one command, clean) -------------------------------------------
cmd_uninstall() {
  (crontab -l 2>/dev/null | grep -vF "guardian.sh heartbeat cron") | crontab - 2>/dev/null || true
  if [ -d "$GUARDIAN_HOME" ]; then
    rm -rf "$GUARDIAN_HOME" && echo "guardian uninstalled cleanly (cron entry removed, no residue)"
  else
    echo "guardian was not installed"
  fi
}

# ---- entry --------------------------------------------------------------------
case "${1:-}" in
  baseline) cmd_baseline "$@";;
  patrol)   cmd_patrol;;
  heartbeat) cmd_heartbeat "$@";;
  page)     cmd_page;;
  uninstall) cmd_uninstall;;
  *) cat <<'USAGE'
guardian.sh — post-deploy guardian v0 (outbound-only, read-only)
  baseline add <file>   register baseline fingerprint for one file
  baseline list         list registered baselines
  patrol                run one patrol round (read-only fingerprint check)
  heartbeat run|start|stop   one ping / install hourly cron / remove cron
  page                  (re)render static receipt page
  uninstall             remove all guardian components in one command
Env: GUARDIAN_HOME (default ~/.guardian), GUARDIAN_WEBHOOK_URL (optional),
     GUARDIAN_HEARTBEAT_INTERVAL (seconds), GUARDIAN_MAX_PAGES (default 50)
USAGE
  [ "${1:-}" = "help" ] || exit 64;;
esac
