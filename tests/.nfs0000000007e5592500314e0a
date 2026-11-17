#!/usr/bin/env bash
# test_guardian_e2e.sh — acceptance test for guardian v0
# Flow: install → baseline → patrol(OK) → drift → patrol(warn/fault) → page → uninstall
# Acceptance criteria (per design doc):
#   1. full sandbox flow passes
#   2. resource footprint: no persistent daemon (cron-driven one-shot)
#   3. uninstall: one command, no residue
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
G="$SCRIPT_DIR/guardian/guardian.sh"
TH="$(mktemp -d /tmp/guardian-e2e-XXXX)"
export GUARDIAN_HOME="$TH/home"
PASS=0; FAIL=0
ok() { echo "PASS: $1"; PASS=$((PASS+1)); }
bad() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }
cleanup() { rm -rf "$TH"; }
trap cleanup EXIT

# --- setup: two files as deploy artifacts
echo "artifact-A-v1" > "$TH/a.conf"
echo "artifact-B-v1" > "$TH/b.conf"

# --- 1. baseline registration
"$G" baseline add "$TH/a.conf" >/dev/null && ok "baseline add A" || bad "baseline add A"
"$G" baseline add "$TH/b.conf" >/dev/null && ok "baseline add B" || bad "baseline add B"

# --- 2. patrol round 1: expect info
"$G" patrol >/dev/null 2>&1
grep -q '"level":"info"' "$GUARDIAN_HOME/reports/round-000001.json" && ok "round1 level=info" || bad "round1 level"

# --- 3. drift (A modified => warn), missing (B removed => fault)
echo "tampered" > "$TH/a.conf"; rm -f "$TH/b.conf"
"$G" patrol >/dev/null 2>&1
R2="$GUARDIAN_HOME/reports/round-000002.json"
grep -q '"level":"fault"' "$R2" && ok "round2 level=fault (missing => fault)" || bad "round2 level"
grep -q "DRIFT" "$R2" && ok "round2 records DRIFT" || bad "round2 DRIFT"
grep -q "MISSING" "$R2" && ok "round2 records MISSING" || bad "round2 MISSING"

# --- 3b. warn case: drift without missing
echo "artifact-B-restored" > "$TH/b.conf"
"$G" baseline add "$TH/b.conf" >/dev/null
echo "tampered-2" > "$TH/a.conf"
"$G" patrol >/dev/null 2>&1
grep -q '"level":"warn"' "$GUARDIAN_HOME/reports/round-000003.json" && ok "round3 level=warn (drift only)" || bad "round3 level"

# --- 4. receipt page shows history
"$G" page >/dev/null 2>&1
PAGE="$GUARDIAN_HOME/page/receipt.html"
grep -q "DRIFT" "$PAGE" && ok "page shows DRIFT" || bad "page DRIFT"
grep -q "MISSING" "$PAGE" && ok "page shows MISSING" || bad "page MISSING"
grep -q 'class=fault' "$PAGE" && ok "page colors fault rows" || bad "page fault color"

# --- 5. heartbeat one-shot (outbound payload only)
"$G" heartbeat run >/dev/null 2>&1
grep -q '"type":"heartbeat"' "$GUARDIAN_HOME/state/last-heartbeat.json" && ok "heartbeat payload written" || bad "heartbeat payload"

# --- 6. resource footprint: no resident process of our own
if ! pgrep -f "guardian.sh patrol" >/dev/null 2>&1; then ok "no resident daemon (cron one-shot design)"; else bad "resident process found"; fi

# --- 7. uninstall: one command, no residue
"$G" uninstall >/dev/null 2>&1
if [ ! -d "$GUARDIAN_HOME" ]; then ok "uninstall removes all files"; else bad "uninstall residue"; fi
if ! crontab -l 2>/dev/null | grep -q "guardian"; then ok "no cron residue (or cron unavailable in sandbox)"; else bad "cron residue"; fi

echo "----"
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]