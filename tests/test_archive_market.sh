#!/usr/bin/env bash
# test_archive_market.sh — B3 deployment-archive market v0 acceptance:
#   ledger → archive build → public fields only → idempotent rebuild.
set -u
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
check() { # $1 desc, $2 condition result (0/1)
  if [ "$2" -eq 0 ]; then ok "$1"; else bad "$1"; fi
}

SBOX=$(mktemp -d)
MODDIR="$(cd "$(dirname "$0")/../modules" && pwd)"
export DEPLOY_LEDGER="$SBOX/ledger.jsonl"

# --- fixture: two deploy reports, one carrying a customer-secret string ------
SECRET="CUSTOMER-SECRET-9f3a1"
printf '{"mode":"auto","profile":"deepseek-codex","snapshot":"%s/pkg-codex.tar.gz","status":"verified","customer_note":"%s","workdir":"%s"}' "$SBOX" "$SECRET" "$SBOX" > "$SBOX/r1.json"
printf '{"mode":"auto","profile":"generic-npm-agent","snapshot":"%s/pkg-agent.tar.gz","status":"recorded"}' "$SBOX" > "$SBOX/r2.json"

python3 "$MODDIR/auto-ledger-record.py" "$SBOX/r1.json" >/dev/null 2>&1
check "ledger records report 1" $?
python3 "$MODDIR/auto-ledger-record.py" "$SBOX/r2.json" >/dev/null 2>&1
check "ledger records report 2" $?

# --- build archive ------------------------------------------------------------
python3 "$MODDIR/archive-market.py" build --out "$SBOX/archive" >/dev/null 2>&1
check "archive build exits clean" $?

python3 - "$SBOX/archive" <<'PY'
import json,sys,os
d=json.load(open(os.path.join(sys.argv[1],"ledger.json")))
pk=d["packages"]
assert d["count"]==2 and len(pk)==2, "entry count"
assert pk[0]["package_id"].startswith("DK-"), "package id format"
assert pk[0]["status"]=="verified" and pk[1]["status"]=="recorded", "status passthrough"
assert pk[0]["profile"]=="deepseek-codex", "profile passthrough"
assert pk[0]["package"]=="pkg-codex.tar.gz", "snapshot basename only"
assert all(len(p["sha256"])==64 for p in pk), "full sha256 present"
PY
check "ledger.json: 2 entries, public fields well-formed" $?

grep -q "DK-" "$SBOX/archive/index.html" && r=0 || r=1
check "index.html shows package IDs" $r
grep -q "pkg-codex.tar.gz" "$SBOX/archive/index.html" && r=0 || r=1
check "index.html shows package names" $r
grep -q "Deployment Archive" "$SBOX/archive/index.html" && r=0 || r=1
check "index.html renders page shell" $r

# --- privacy: customer content and absolute paths must not leak ---------------
grep -q "$SECRET" "$SBOX/archive/ledger.json" 2>/dev/null && r=1 || r=0
check "ledger.json leaks no customer content" $r
grep -q "$SECRET" "$SBOX/archive/index.html" 2>/dev/null && r=1 || r=0
check "index.html leaks no customer content" $r
grep -qF "$SBOX" "$SBOX/archive/ledger.json" 2>/dev/null && r=1 || r=0
check "ledger.json leaks no absolute paths" $r
grep -qF "$SBOX" "$SBOX/archive/index.html" 2>/dev/null && r=1 || r=0
check "index.html leaks no absolute paths" $r

# --- idempotent rebuild --------------------------------------------------------
S1=$(sha256sum "$SBOX/archive/ledger.json" | cut -d' ' -f1)
python3 "$MODDIR/archive-market.py" build --out "$SBOX/archive" >/dev/null 2>&1
S2=$(sha256sum "$SBOX/archive/ledger.json" | cut -d' ' -f1)
[ "$S1" = "$S2" ] && r=0 || r=1
check "rebuild is idempotent (byte-identical ledger.json)" $r

# --- torn tail line never blocks the build -------------------------------------
echo '{"ts":"torn","sha' >> "$DEPLOY_LEDGER"
python3 "$MODDIR/archive-market.py" build --out "$SBOX/archive" >/dev/null 2>&1
check "torn ledger tail line tolerated" $?

rm -rf "$SBOX"
echo "passed=$PASS failed=$FAIL"
[ $FAIL -eq 0 ]
