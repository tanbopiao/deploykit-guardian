@echo off
rem start.cmd — Windows thin wrapper for start.py.
rem Picks py launcher when available, falls back to python. All real logic in start.py.
setlocal
set "PY=python"
py --version >nul 2>nul && set "PY=py"
"%PY%" "%~dp0start.py" %*
exit /b %ERRORLEVEL%
