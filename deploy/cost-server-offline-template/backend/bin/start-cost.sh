#!/usr/bin/env bash
set -euo pipefail
BACKEND_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$BACKEND_ROOT/config/cost-server.env"
JAR_FILE="$BACKEND_ROOT/app/cost-server.jar"
CONFIG_FILE="$BACKEND_ROOT/config/application-intranet.yml"
PID_FILE="$BACKEND_ROOT/run/cost-server.pid"
mkdir -p "$BACKEND_ROOT/run" "$BACKEND_ROOT/logs"
[[ -f "$ENV_FILE" ]] || { echo "Missing $ENV_FILE" >&2; exit 1; }
[[ -f "$JAR_FILE" ]] || { echo "Missing $JAR_FILE" >&2; exit 1; }
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a
: "${NACOS_SERVER_ADDR:?NACOS_SERVER_ADDR is required}"
: "${NACOS_NAMESPACE:?NACOS_NAMESPACE is required}"
: "${COST_DATASOURCE_URL:?COST_DATASOURCE_URL is required}"
: "${COST_DATASOURCE_USERNAME:?COST_DATASOURCE_USERNAME is required}"
: "${COST_DATASOURCE_PASSWORD:?COST_DATASOURCE_PASSWORD is required}"
: "${COST_REDIS_HOST:?COST_REDIS_HOST is required}"
if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "cost-server is already running, pid=$(cat "$PID_FILE")" >&2
  exit 1
fi
cd "$BACKEND_ROOT"
nohup java ${JAVA_OPTS:--Xms512m -Xmx2048m} -jar "$JAR_FILE" \
  --spring.profiles.active=jt \
  "--spring.config.additional-location=optional:file:$CONFIG_FILE" \
  >> "$BACKEND_ROOT/logs/console.log" 2>&1 &
echo $! > "$PID_FILE"
echo "cost-server started, pid=$!"
