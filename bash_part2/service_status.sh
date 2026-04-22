#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="${LAB_DIR}/service.pid"
STATE_DIR="${LAB_DIR}/state"
CURRENT_VERSION_FILE="${STATE_DIR}/current_version"

echo "=== Service Process ==="
if [[ -f "${PID_FILE}" ]]; then
  PID="$(cat "${PID_FILE}")"
  if kill -0 "${PID}" 2>/dev/null; then
    echo "RUNNING pid=${PID}"
  else
    echo "STOPPED (stale pid file)"
  fi
else
  echo "STOPPED"
fi

echo
echo "=== Health Check ==="
curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:8080/health || true
curl -s http://localhost:8080/health || true
echo

echo
echo "=== Deployment State ==="
if [[ -f "${CURRENT_VERSION_FILE}" ]]; then
  echo "current_version=$(cat "${CURRENT_VERSION_FILE}")"
fi
for f in "${STATE_DIR}"/instances/*.version; do
  [[ -e "$f" ]] || continue
  echo "$(basename "$f" .version)=$(cat "$f")"
done
