#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="/opt/payment-api-lab"
SERVICE_NAME="payment-api.service"

echo "[INFO] Creating lab directory: ${LAB_DIR}"
mkdir -p "${LAB_DIR}"

echo "[INFO] Copying app.py"
cp ./app.py "${LAB_DIR}/app.py"
chmod +x "${LAB_DIR}/app.py"

echo "[INFO] Installing systemd service"
cp ./payment-api.service "/etc/systemd/system/${SERVICE_NAME}"

echo "[INFO] Reloading systemd"
systemctl daemon-reload

echo "[INFO] Enabling service"
systemctl enable payment-api

echo "[INFO] Starting service"
systemctl restart payment-api

echo "[INFO] Current service status:"
systemctl --no-pager --full status payment-api || true

echo "[INFO] Health check:"
curl -s http://localhost:8080/health || true

echo "[INFO] Lab setup complete."
