#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="${LAB_DIR}/service.pid"

if [[ -f "${PID_FILE}" ]]; then
  PID="$(cat "${PID_FILE}")"
  if kill -0 "${PID}" 2>/dev/null; then
    kill "${PID}" || true
    echo "[INFO] Stopped service PID ${PID}"
  else
    echo "[WARNING] PID ${PID} not running"
  fi
  rm -f "${PID_FILE}"
else
  echo "[WARNING] No PID file found"
fi
