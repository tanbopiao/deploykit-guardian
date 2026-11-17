#!/usr/bin/env bash
# start.command — macOS thin wrapper for start.py (double-click friendly).
# Double-clicking in Finder runs this in Terminal; we cd into the repo first
# (Terminal may start at /) and pause on error so the window stays readable.
cd "$(dirname "$0")" || exit 1
PY=python3
command -v python3 >/dev/null 2>&1 || PY=python
"$PY" ./start.py "$@"
RC=$?
if [ "$RC" -ne 0 ] && [ -t 0 ]; then
  printf '\n[start.command] exited with %s — press Enter to close. ' "$RC"
  read -r _
fi
exit "$RC"
