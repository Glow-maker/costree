#!/usr/bin/env bash
set -euo pipefail
BACKEND_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PID_FILE="$BACKEND_ROOT/run/cost-server.pid"
if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "cost-server: running, pid=$(cat "$PID_FILE")"
  exit 0
fi
echo 'cost-server: stopped'
exit 1
