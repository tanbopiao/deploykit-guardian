#!/usr/bin/env python3
"""start.py — unified cross-platform entry for DeployKit Guardian.

One entry, all platforms. Subcommands:
  deploy    B1 one-click deploy pipeline
  guardian  B2 post-deploy guardian

Platform delegation contract:
  - POSIX (Linux / macOS / WSL2): delegate to the existing bash pipeline
    (start-auto-deploy.sh / guardian/guardian.sh). Behavior is unchanged.
  - Windows native: delegate to the native adapter layer
    (guardian/adapters/windows/guardian.ps1 for guardian; B1 deploy via WSL2
    when available, clear guidance otherwise).

Thin wrappers (start.sh / start.command / start.cmd) all land here.
"""

import os
import re
import shutil
import subprocess
import sys

REPO_ROOT = os.path.dirname(os.path.abspath(__file__))
POSIX_DEPLOY = os.path.join(REPO_ROOT, "start-auto-deploy.sh")
POSIX_GUARDIAN = os.path.join(REPO_ROOT, "guardian", "guardian.sh")
WIN_GUARDIAN = os.path.join(
    REPO_ROOT, "guardian", "adapters", "windows", "guardian.ps1")

IS_WINDOWS = sys.platform.startswith("win")

EXIT_OK = 0
EXIT_USAGE = 64


HELP = """\
start.py — unified cross-platform entry for DeployKit Guardian

Usage:
  start.py deploy <profile.json> [--dry-run] [--base-url URL] [--model MODEL]
  start.py guardian <guardian-args>
      e.g. start.py guardian baseline add <file>
           start.py guardian heartbeat start|stop|run|cron
           start.py guardian patrol | page | uninstall

Platform shortcuts (thin wrappers that all call start.py):
  Linux / macOS / WSL2    ./start.sh deploy profiles/codex.json
  macOS (double-click)    open start.command        (runs in Terminal)
  Windows (cmd / double)  start.cmd guardian heartbeat start

Platform behavior:
  Linux / macOS / WSL2    deploy -> start-auto-deploy.sh (bash pipeline,
                          behavior unchanged)
                          guardian -> guardian/guardian.sh (cron heartbeat,
                          default; optional launchd adapter for macOS:
                          guardian/adapters/macos/)
  Windows native          guardian -> guardian/adapters/windows/guardian.ps1
                          (schtasks hourly heartbeat, Get-FileHash SHA256
                          patrol, Invoke-WebRequest outbound-only reporting,
                          receipt page, clean uninstall)
                          deploy   -> B1 pipeline is POSIX bash; runs via WSL2
                          when available, otherwise prints setup guidance.

Design guarantees (all platforms): outbound-only, read-only patrol,
fingerprints only (never file contents), one-command clean uninstall.
"""


def _fail(msg, code=EXIT_USAGE):
    print("[start.py] %s" % msg, file=sys.stderr)
    return code


# ---- Windows path helpers ----------------------------------------------------
def to_wsl_path(path):
    """Translate a Windows absolute path to its /mnt/... WSL2 equivalent."""
    path = os.path.abspath(path)
    m = re.match(r"^([A-Za-z]):(.*)$", path)
    if not m:
        return path
    drive, tail = m.groups()
    return "/mnt/%s%s" % (drive.lower(), tail.replace("\\", "/"))


# ---- deploy ------------------------------------------------------------------
def deploy_posix(rest):
    """POSIX: delegate to the existing bash orchestrator, unchanged."""
    return subprocess.call(["bash", POSIX_DEPLOY] + list(rest))


def deploy_windows(rest):
    """Windows native: B1 pipeline is bash; delegate to WSL2 if available."""
    wsl = shutil.which("wsl.exe") or shutil.which("wsl")
    if wsl:
        script = to_wsl_path(POSIX_DEPLOY)
        cmd = [wsl, "bash", script] + list(rest)
        print("[start.py] Windows native: delegating B1 deploy to WSL2 pipeline:")
        print("           %s" % " ".join(cmd))
        return subprocess.call(cmd)
    return _fail(
        "B1 deploy pipeline is POSIX bash. On native Windows install WSL2 "
        "(wsl --install) and rerun from the repo, or run the deploy on "
        "Linux/macOS. The guardian works natively on Windows: "
        "start.py guardian heartbeat start",
        EXIT_USAGE)


# ---- guardian ----------------------------------------------------------------
def guardian_posix(rest):
    """POSIX: delegate to the existing cron-based guardian, unchanged."""
    return subprocess.call(["bash", POSIX_GUARDIAN] + list(rest))


def guardian_windows(rest):
    """Windows native: delegate to the PowerShell adapter layer."""
    if not os.path.isfile(WIN_GUARDIAN):
        return _fail("Windows adapter not found: %s" % WIN_GUARDIAN, EXIT_USAGE)
    pwsh = shutil.which("pwsh") or shutil.which("powershell") \
        or shutil.which("powershell.exe")
    if not pwsh:
        return _fail(
            "PowerShell not found; the Windows guardian adapter requires "
            "Windows PowerShell 5.1+ (built into Windows) or PowerShell 7+.",
            EXIT_USAGE)
    return subprocess.call(
        [pwsh, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
         WIN_GUARDIAN] + list(rest))


# ---- entry -------------------------------------------------------------------
def main(argv):
    if not argv or argv[0] in ("-h", "--help", "help"):
        print(HELP)
        return EXIT_OK
    cmd, rest = argv[0], argv[1:]
    if cmd == "deploy":
        return deploy_windows(rest) if IS_WINDOWS else deploy_posix(rest)
    if cmd == "guardian":
        if not rest:
            return _fail("guardian needs arguments; try "
                         "'start.py guardian help' or 'start.py --help'")
        return guardian_windows(rest) if IS_WINDOWS else guardian_posix(rest)
    return _fail("unknown subcommand: %s (see --help)" % cmd)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
