#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export ENVIRONMENT="${environment}"
export APP_PORT="${app_port}"
export DATABASE_URL="${database_url}"
export APP_DIR="/opt/academy-control-api"

apt-get update
apt-get install -y python3 python3-pip nginx

mkdir -p "$APP_DIR/app"

cat > "$APP_DIR/requirements.txt" <<'REQ'
fastapi==0.115.6
uvicorn==0.34.0
REQ

cat > "$APP_DIR/app/db.py" <<'PY'
from __future__ import annotations

import os
import sqlite3
from pathlib import Path


def sqlite_path() -> Path:
    url = os.environ["DATABASE_URL"]
    return Path(url.replace("sqlite:///", "", 1))


def connect() -> sqlite3.Connection:
    return sqlite3.connect(sqlite_path())


def migrate() -> None:
    path = sqlite_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(path) as conn:
        conn.execute("create table if not exists students (id integer primary key, username text)")
        conn.execute("create table if not exists assignments (id integer primary key, status text)")
        conn.execute("insert or ignore into students(id, username) values (1, 'john.doe')")
        conn.execute("insert or ignore into assignments(id, status) values (1, 'in_progress')")
        conn.commit()
PY

cat > "$APP_DIR/app/main.py" <<'PY'
from __future__ import annotations

import os
from fastapi import FastAPI, HTTPException
from app import db

app = FastAPI(title="Academy Control API")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/ready")
def ready():
    try:
        with db.connect() as conn:
            conn.execute("select count(*) from assignments").fetchone()
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"database connection failed: {exc}")
    return {"status": "ready", "environment": os.getenv("ENVIRONMENT", "dev")}


@app.get("/stats")
def stats():
    with db.connect() as conn:
        students = conn.execute("select count(*) from students").fetchone()[0]
        assignments = conn.execute("select count(*) from assignments").fetchone()[0]
    return {
        "environment": os.getenv("ENVIRONMENT", "dev"),
        "version": "1.3.0",
        "students": students,
        "assignments": {"total": assignments},
        "database": {"status": "connected", "engine": "sqlite"},
    }
PY

python3 -m pip install -r "$APP_DIR/requirements.txt"

if [ "$ENVIRONMENT" = "dev" ]; then
  cd "$APP_DIR"
  python3 -c "from app import db; db.migrate()"
fi

cat > /etc/systemd/system/academy-control-api.service <<SERVICE
[Unit]
Description=Academy Control API
After=network.target

[Service]
WorkingDirectory=$APP_DIR
Environment=ENVIRONMENT=$ENVIRONMENT
Environment=DATABASE_URL=$DATABASE_URL
ExecStart=/usr/local/bin/uvicorn app.main:app --host 127.0.0.1 --port $APP_PORT
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SERVICE

cat > /etc/nginx/sites-available/academy-control-api <<NGINX
server {
  listen 80;
  server_name _;

  location / {
    proxy_pass http://127.0.0.1:$APP_PORT;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
  }
}
NGINX

ln -sf /etc/nginx/sites-available/academy-control-api /etc/nginx/sites-enabled/academy-control-api
rm -f /etc/nginx/sites-enabled/default

systemctl daemon-reload
systemctl enable academy-control-api
systemctl restart academy-control-api
systemctl restart nginx
