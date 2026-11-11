#!/usr/bin/env bash
# One-command local run (macOS / Linux): installs dependencies, builds the UI,
# loads the demo data on first run and serves everything at http://localhost:8000
#
#   ./run.sh              start (demo accounts loaded into an empty database)
#   PORT=9000 ./run.sh    use another port
#   SEED_DEMO=false ./run.sh   start without demo data
set -euo pipefail
cd "$(dirname "$0")"

PORT="${PORT:-8000}"
export SEED_DEMO="${SEED_DEMO:-true}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Error: $1 is not installed. $2"; exit 1; }; }

PY="$(command -v python3 || command -v python || true)"
[ -n "$PY" ] || { echo "Error: Python 3.11 or newer is required (https://www.python.org/downloads/)."; exit 1; }
"$PY" -c 'import sys; sys.exit(sys.version_info < (3, 11))' \
  || { echo "Error: Python 3.11 or newer is required (found $("$PY" --version 2>&1))."; exit 1; }
need npm "Install Node.js 20 or newer from https://nodejs.org/"

echo "==> Backend: Python packages"
[ -x backend/.venv/bin/python ] || "$PY" -m venv backend/.venv
VPY="backend/.venv/bin/python"
"$VPY" -m pip install --quiet --upgrade pip
"$VPY" -m pip install --quiet -r backend/requirements.txt

echo "==> Frontend: building the web app"
(
  cd frontend
  [ -d node_modules ] || npm ci --no-audit --no-fund
  npm run build --silent
)

echo "==> Database: migrations and demo data"
cd backend
.venv/bin/python -m alembic upgrade head
.venv/bin/python -m app.cli bootstrap

URL="http://localhost:${PORT}"
echo
echo "SAAP is starting at ${URL}   (press Ctrl+C to stop)"
if [ "$SEED_DEMO" = "true" ]; then
  echo "Demo logins: admin@saap.edu / Admin@123 · neha@saap.edu / Faculty@123 · student@saap.edu / Student@123"
fi
( sleep 3; { command -v open >/dev/null && open "$URL"; } || { command -v xdg-open >/dev/null && xdg-open "$URL"; } ) >/dev/null 2>&1 &
exec .venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port "$PORT"
