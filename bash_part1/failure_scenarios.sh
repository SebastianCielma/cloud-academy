#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage:
  ./failure_scenarios.sh stop-service
  ./failure_scenarios.sh break-health
  ./failure_scenarios.sh restore-health
  ./failure_scenarios.sh wrong-port
  ./failure_scenarios.sh restore-port
  ./failure_scenarios.sh status
EOF
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

case "$1" in
  stop-service)
    systemctl stop payment-api
    echo "[INFO] payment-api stopped"
    ;;
  break-health)
    mkdir -p /etc/systemd/system/payment-api.service.d
    cat > /etc/systemd/system/payment-api.service.d/override.conf <<CONF
[Service]
Environment=BROKEN_HEALTH=true
CONF
    systemctl daemon-reload
    systemctl restart payment-api
    echo "[INFO] payment-api restarted with broken health endpoint"
    ;;
  restore-health)
    rm -f /etc/systemd/system/payment-api.service.d/override.conf
    systemctl daemon-reload
    systemctl restart payment-api
    echo "[INFO] payment-api health restored"
    ;;
  wrong-port)
    mkdir -p /etc/systemd/system/payment-api.service.d
    cat > /etc/systemd/system/payment-api.service.d/override.conf <<CONF
[Service]
Environment=APP_PORT=9090
Environment=BROKEN_HEALTH=false
CONF
    systemctl daemon-reload
    systemctl restart payment-api
    echo "[INFO] payment-api restarted on port 9090"
    ;;
  restore-port)
    rm -f /etc/systemd/system/payment-api.service.d/override.conf
    systemctl daemon-reload
    systemctl restart payment-api
    echo "[INFO] payment-api port restored to 8080"
    ;;
  status)
    systemctl --no-pager --full status payment-api || true
    ss -ltnp | grep -E ':8080|:9090' || true
    curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:8080/health || true
    curl -s -o /dev/null -w "HTTP %{http_code}\n" http://localhost:9090/health || true
    ;;
  *)
    usage
    exit 1
    ;;
esac
