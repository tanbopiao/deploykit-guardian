#!/usr/bin/env bash
# start.sh — POSIX thin wrapper for start.py (Linux / macOS / WSL2).
# Picks python3 when available, falls back to python. All real logic in start.py.
PY=python3
command -v python3 >/dev/null 2>&1 || PY=python
exec "$PY" "$(cd "$(dirname "$0")" && pwd)/start.py" "$@"
