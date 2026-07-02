#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/academy-control-api}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
DATABASE_URL="${DATABASE_URL:-sqlite:////opt/academy-control-api/dev.sqlite}"

echo "Bootstrapping academy-control-api"
echo "ENVIRONMENT=${ENVIRONMENT}"
echo "DATABASE_URL=${DATABASE_URL}"

python -m pip install -r "${APP_DIR}/requirements.txt"

if [ "$ENVIRONMENT" = "dev" ]; then
  echo "Running database migrations for dev"
  python "${APP_DIR}/app/db.py" migrate
fi

cat > /etc/systemd/system/academy-control-api.service <<SERVICE
[Unit]
Description=Academy Control API
After=network.target

[Service]
WorkingDirectory=${APP_DIR}
Environment=ENVIRONMENT=${ENVIRONMENT}
Environment=DATABASE_URL=${DATABASE_URL}
ExecStart=/usr/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable academy-control-api
systemctl restart academy-control-api
