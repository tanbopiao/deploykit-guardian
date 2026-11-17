#!/usr/bin/env bash
# test_start_py_dispatch.sh — cross-platform entry (start.py) dispatch test.
#
# Scope (this sandbox is Linux):
#   - start.py subcommand dispatch on POSIX (real runs: delegated to the real
#     scripts, so existing behavior is exercised unchanged)
#   - thin wrappers start.sh / start.command / start.cmd (syntax-level checks)
#   - Windows adapter guardian.ps1 and macOS launchd adapter: logic is verified
#     when pwsh is available (core adapter logic runs on Linux pwsh too);
#     otherwise these are labeled SKIP and noted as "real-environment
#     first-run must be confirmed once" — never counted as passing.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
START_PY="$SCRIPT_DIR/start.py"
START_SH="$SCRIPT_DIR/start.sh"
START_CMD="$SCRIPT_DIR/start.cmd"
START_CMD_MAC="$SCRIPT_DIR/start.command"
WIN_PS1="$SCRIPT_DIR/guardian/adapters/windows/guardian.ps1"
MACOS_LAUNCHD="$SCRIPT_DIR/guardian/adapters/macos/install-launchd.sh"
PY_BIN=python3
command -v python3 >/dev/null 2>&1 || PY_BIN=python

PASS=0; FAIL=0; SKIP=0
ok()   { echo "PASS: $1"; PASS=$((PASS+1)); }
bad()  { echo "FAIL: $1"; FAIL=$((FAIL+1)); }
skip() { echo "SKIP: $1"; SKIP=$((SKIP+1)); }

# --- 1. help entry -------------------------------------------------------------
"$PY_BIN" "$START_PY" --help >/tmp/sp-help.txt 2>&1 \
  && ok "start.py --help exits 0" || bad "start.py --help exits 0"
grep -q "deploy" /tmp/sp-help.txt && grep -q "guardian" /tmp/sp-help.txt \
  && ok "help lists deploy and guardian subcommands" || bad "help subcommands"
grep -q "Windows" /tmp/sp-help.txt && grep -q "start.cmd" /tmp/sp-help.txt \
  && ok "help lists platform usage (Windows / start.cmd)" || bad "help platform usage"
"$PY_BIN" "$START_PY" no-such-subcommand >/dev/null 2>&1 && RC=$? || RC=$?
[ "$RC" -eq 64 ] && ok "unknown subcommand -> usage error 64" || bad "unknown subcommand rc"

# --- 2. guardian dispatch (delegates to real guardian.sh, behavior unchanged) ---
"$PY_BIN" "$START_PY" guardian help >/dev/null 2>&1 \
  && ok "start.py guardian help -> guardian.sh (exit 0)" || bad "guardian help"
"$PY_BIN" "$START_PY" guardian baseline list >/dev/null 2>&1 \
  && ok "start.py guardian baseline list -> guardian.sh" || bad "baseline list"
"$PY_BIN" "$START_PY" guardian not-a-command >/dev/null 2>&1 && RC=$? || RC=$?
[ "$RC" -eq 64 ] && ok "guardian.sh usage errors propagate through start.py" || bad "guardian error rc"

# --- 3. deploy dispatch (no-arg -> orchestrator usage error, real delegation) ---
"$PY_BIN" "$START_PY" deploy >/dev/null 2>&1 && RC=$? || RC=$?
[ "$RC" -eq 64 ] && ok "start.py deploy -> start-auto-deploy.sh (usage rc 64)" || bad "deploy dispatch"
bash start-auto-deploy.sh >/dev/null 2>&1 && RC=$? || RC=$?
[ "$RC" -eq 64 ] && ok "direct start-auto-deploy.sh behavior unchanged (rc 64)" || bad "direct orchestrator"

# --- 4. POSIX thin wrappers ------------------------------------------------------
"$START_SH" --help >/dev/null 2>&1 \
  && ok "start.sh resolves python and runs start.py" || bad "start.sh"
bash -n "$START_SH" && ok "start.sh syntax OK" || bad "start.sh syntax"
bash -n "$START_CMD_MAC" && ok "start.command syntax OK" || bad "start.command syntax"
grep -q '%~dp0start.py' "$START_CMD" \
  && ok "start.cmd references start.py via %~dp0" || bad "start.cmd content"
grep -q 'python' "$START_CMD" && grep -q 'py' "$START_CMD" \
  && ok "start.cmd has py/python fallback logic" || bad "start.cmd fallback"
grep -q 'cd "$(dirname "$0")"' "$START_CMD_MAC" \
  && ok "start.command cd's to repo (double-click friendly)" || bad "start.command cd"

# --- 5. macOS launchd adapter (structure check; real load needs macOS) ----------
if bash -n "$MACOS_LAUNCHD" 2>/dev/null; then
  ok "macOS launchd adapter syntax OK (bash -n)"
else
  bad "macOS launchd adapter syntax"
fi
"$PY_BIN" - "$SCRIPT_DIR" <<'PYEOF' \
  && ok "launchd plist template well-formed XML (logic check)" \
  || bad "launchd plist template"
import subprocess, sys, re, os
script = os.path.join(sys.argv[1], "guardian", "adapters", "macos", "install-launchd.sh")
src = open(script).read()
m = re.search(r"cat > \"\$PLIST\" <<EOF\n(.*?)\nEOF", src, re.S)
assert m, "plist heredoc not found"
import tempfile
with tempfile.NamedTemporaryFile("w", suffix=".plist", delete=False) as f:
    f.write(m.group(1).replace("$PLIST_ID", "com.deploykit.guardian.heartbeat")
                       .replace("$SELF", "/home/u/.guardian/guardian.sh")
                       .replace("$GUARDIAN_HOME", "/home/u/.guardian"))
    path = f.name
import xml.dom.minidom
xml.dom.minidom.parse(path)
PYEOF

# --- 6. Windows adapter ---------------------------------------------------------
if command -v pwsh >/dev/null 2>&1; then
  # 6a. syntax-level: PowerShell parser accepts the file
  ERRS=$(pwsh -NoProfile -Command '
    $t=$null;$e=$null
    [System.Management.Automation.Language.Parser]::ParseFile("'"$WIN_PS1"'",[ref]$t,[ref]$e)|Out-Null
    if($e.Count){$e|%{"$($_.Extent.StartLineNumber):$($_.Message)"};exit 1}else{exit 0}')
  [ $? -eq 0 ] && ok "guardian.ps1 parses cleanly (PowerShell AST)" || bad "guardian.ps1 parse: $ERRS"
  # 6b. logic: core adapter flow runs under pwsh on Linux (no schtasks/Invoke needed)
  TH=$(mktemp -d /tmp/guardian-win-XXXX); export GUARDIAN_HOME="$TH/home"
  echo artifact > "$TH/a.conf"
  pwsh -NoProfile -File "$WIN_PS1" baseline add "$TH/a.conf" >/dev/null 2>&1 \
    && ok "guardian.ps1 baseline add (pwsh-on-linux)" || bad "guardian.ps1 baseline add"
  pwsh -NoProfile -File "$WIN_PS1" patrol >/dev/null 2>&1
  grep -q '"level":"info"' "$GUARDIAN_HOME/reports/round-000001.json" \
    && ok "guardian.ps1 patrol info (pwsh-on-linux)" || bad "guardian.ps1 patrol info"
  echo tampered > "$TH/a.conf"
  pwsh -NoProfile -File "$WIN_PS1" patrol >/dev/null 2>&1
  grep -q '"level":"warn"' "$GUARDIAN_HOME/reports/round-000002.json" \
    && ok "guardian.ps1 patrol warn on drift (pwsh-on-linux)" || bad "guardian.ps1 patrol warn"
  pwsh -NoProfile -File "$WIN_PS1" heartbeat run >/dev/null 2>&1
  grep -q '"type":"heartbeat"' "$GUARDIAN_HOME/state/last-heartbeat.json" \
    && ok "guardian.ps1 heartbeat payload (pwsh-on-linux)" || bad "guardian.ps1 heartbeat"
  pwsh -NoProfile -File "$WIN_PS1" page >/dev/null 2>&1
  grep -q "Guardian Receipts" "$GUARDIAN_HOME/page/receipt.html" \
    && ok "guardian.ps1 receipt page (pwsh-on-linux)" || bad "guardian.ps1 page"
  pwsh -NoProfile -File "$WIN_PS1" uninstall >/dev/null 2>&1
  [ ! -d "$GUARDIAN_HOME" ] && ok "guardian.ps1 clean uninstall (pwsh-on-linux)" || bad "guardian.ps1 uninstall residue"
  rm -rf "$TH"
else
  skip "pwsh not available: guardian.ps1 checked at logic level only; real Windows first-run must be confirmed once"
fi
skip "schtasks/launchd scheduling cannot run on this sandbox: Windows task install and macOS launchctl load need a real-environment first run"

# --- 7. adapters layer exists with contract doc --------------------------------
[ -f "$SCRIPT_DIR/guardian/adapters/README.md" ] \
  && ok "guardian/adapters contract documented" || bad "adapters README"

echo "----"
echo "passed=$PASS failed=$FAIL skipped=$SKIP"
[ "$FAIL" -eq 0 ]
