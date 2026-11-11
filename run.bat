@echo off
rem One-click local run (Windows): installs dependencies, builds the UI,
rem loads the demo data on first run and serves everything at http://localhost:8000
rem Double-click this file, or run it from a Command Prompt.
setlocal
cd /d "%~dp0"

if not defined PORT set PORT=8000
if not defined SEED_DEMO set SEED_DEMO=true

set PY=
where py >nul 2>nul && set PY=py -3
if not defined PY (where python >nul 2>nul && set PY=python)
if not defined PY (
  echo Error: Python 3.11 or newer is required. Install it from https://www.python.org/downloads/
  echo and tick "Add python.exe to PATH" during setup.
  goto :fail
)
%PY% -c "import sys; sys.exit(sys.version_info < (3, 11))" || (
  echo Error: Python 3.11 or newer is required.
  goto :fail
)
where npm >nul 2>nul || (
  echo Error: Node.js 20 or newer is required. Install it from https://nodejs.org/
  goto :fail
)

echo ==^> Backend: Python packages
if not exist backend\.venv\Scripts\python.exe %PY% -m venv backend\.venv || goto :fail
backend\.venv\Scripts\python.exe -m pip install --quiet --upgrade pip || goto :fail
backend\.venv\Scripts\python.exe -m pip install --quiet -r backend\requirements.txt || goto :fail

echo ==^> Frontend: building the web app
pushd frontend
if not exist node_modules call npm ci --no-audit --no-fund || (popd & goto :fail)
call npm run build --silent || (popd & goto :fail)
popd

echo ==^> Database: migrations and demo data
cd backend
.venv\Scripts\python.exe -m alembic upgrade head || goto :fail
.venv\Scripts\python.exe -m app.cli bootstrap || goto :fail

echo.
echo SAAP is starting at http://localhost:%PORT%   (close this window or press Ctrl+C to stop)
if /i "%SEED_DEMO%"=="true" echo Demo logins: admin@saap.edu / Admin@123 - neha@saap.edu / Faculty@123 - student@saap.edu / Student@123
rem open the browser once the server has had a few seconds to start
start "" /b powershell -NoProfile -WindowStyle Hidden -Command "Start-Sleep 4; Start-Process 'http://localhost:%PORT%'"
.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port %PORT%
goto :eof

:fail
echo.
echo Setup failed - see the message above.
pause
exit /b 1
