#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${LAB_DIR}/state"
INSTANCES_DIR="${STATE_DIR}/instances"

mkdir -p "${INSTANCES_DIR}"

echo "v1" > "${STATE_DIR}/current_version"
echo "v1" > "${INSTANCES_DIR}/instance-1.version"
echo "v1" > "${INSTANCES_DIR}/instance-2.version"
echo "v1" > "${INSTANCES_DIR}/instance-3.version"

"${LAB_DIR}/start_service.sh" v1

echo "[INFO] Lab reset complete"
