#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-v1}"
BROKEN_V2="${BROKEN_V2:-false}"
LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="${LAB_DIR}/service.pid"
LOG_FILE="${LAB_DIR}/service.log"

stop_existing() {
  if [[ -f "${PID_FILE}" ]]; then
    PID="$(cat "${PID_FILE}")"
    if kill -0 "${PID}" 2>/dev/null; then
      kill "${PID}" || true
      sleep 1
    fi
    rm -f "${PID_FILE}"
  fi
}

case "${VERSION}" in
  v1)
    APP="${LAB_DIR}/app_v1.py"
    ;;
  v2)
    APP="${LAB_DIR}/app_v2.py"
    ;;
  *)
    echo "[ERROR] Unsupported version: ${VERSION}"
    exit 1
    ;;
esac

stop_existing

echo "[INFO] Starting ${VERSION}"
BROKEN_V2="${BROKEN_V2}" nohup python3 "${APP}" > "${LOG_FILE}" 2>&1 &
echo $! > "${PID_FILE}"
sleep 1

if kill -0 "$(cat "${PID_FILE}")" 2>/dev/null; then
  echo "[INFO] ${VERSION} started with PID $(cat "${PID_FILE}")"
else
  echo "[ERROR] Failed to start ${VERSION}"
  exit 1
fi
