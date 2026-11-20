#!/usr/bin/env bash
# test_site_channel.sh — B4 website deployment channel v0 acceptance:
#   intake → board render → status transition → privacy → idempotency.
set -u
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "PASS: $1"; }
bad() { FAIL=$((FAIL+1)); echo "FAIL: $1"; }
check() { if [ "$2" -eq 0 ]; then ok "$1"; else bad "$1"; fi; }

SBOX=$(mktemp -d)
MOD="$(cd "$(dirname "$0")/../modules" && pwd)/site-channel.py"
ORD="$SBOX/orders.jsonl"
SECRET="CUSTOMER-DOMAIN-secret.example"

# --- intake: add two orders, one carrying customer detail in note -----------
python3 "$MOD" intake add --type static-site --note "deploy $SECRET to /var/www" --orders "$ORD" >/dev/null
check "intake add order 1" $?
python3 "$MOD" intake add --type blog --orders "$ORD" >/dev/null
check "intake add order 2" $?

ID1=$(python3 -c "import json;print(json.loads(open('$ORD').read().splitlines()[0])['order_id'])")
python3 "$MOD" intake set-status --id "$ID1" --status deployed --orders "$ORD" >/dev/null
check "intake set-status transitions order" $?

# --- board render -------------------------------------------------------------
python3 "$MOD" board --out "$SBOX/channel" --orders "$ORD" >/dev/null
check "board render exits clean" $?

python3 - "$SBOX/channel" <<'PY'
import json,sys,os
d=json.load(open(os.path.join(sys.argv[1],"orders.json")))
assert d["count"]==2 and len(d["orders"])==2, "order count"
o=d["orders"][0]
assert o["order_id"].startswith("SC-"), "order id format"
assert o["status"]=="deployed", "status transition visible"
assert "note" not in o, "note excluded from public json"
PY
check "orders.json: public fields only, status correct" $?

grep -q "$ID1" "$SBOX/channel/board.html" && r=0 || r=1
check "board shows order IDs" $r
grep -q "deployed" "$SBOX/channel/board.html" && r=0 || r=1
check "board shows status" $r
grep -q "$SECRET" "$SBOX/channel/board.html" 2>/dev/null && r=1 || r=0
check "board leaks no customer note/domain" $r
grep -q "$SECRET" "$SBOX/channel/orders.json" 2>/dev/null && r=1 || r=0
check "orders.json leaks no customer note/domain" $r

# --- guide page ----------------------------------------------------------------
python3 "$MOD" guide --out "$SBOX/channel" >/dev/null
check "guide render exits clean" $?
grep -q "no coding needed" "$SBOX/channel/guide.html" && r=0 || r=1
check "guide page renders wizard steps" $r

# --- idempotent rebuild ---------------------------------------------------------
S1=$(sha256sum "$SBOX/channel/orders.json" | cut -d' ' -f1)
python3 "$MOD" board --out "$SBOX/channel" --orders "$ORD" >/dev/null
S2=$(sha256sum "$SBOX/channel/orders.json" | cut -d' ' -f1)
[ "$S1" = "$S2" ] && r=0 || r=1
check "board rebuild is idempotent" $r

# --- torn tail line tolerated ----------------------------------------------------
echo '{"torn"' >> "$ORD"
python3 "$MOD" board --out "$SBOX/channel" --orders "$ORD" >/dev/null 2>&1
check "torn intake tail line tolerated" $?

rm -rf "$SBOX"
echo "passed=$PASS failed=$FAIL"
[ $FAIL -eq 0 ]
