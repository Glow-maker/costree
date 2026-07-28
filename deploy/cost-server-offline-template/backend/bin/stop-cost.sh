#!/usr/bin/env bash
set -euo pipefail
BACKEND_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PID_FILE="$BACKEND_ROOT/run/cost-server.pid"
[[ -f "$PID_FILE" ]] || { echo 'cost-server is not running'; exit 0; }
pid="$(cat "$PID_FILE")"
if kill -0 "$pid" 2>/dev/null; then
  kill "$pid"
  for _ in {1..30}; do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
fi
rm -f "$PID_FILE"
echo "cost-server stopped, pid=$pid"
