#!/usr/bin/env bash
set -euo pipefail

mkdir -p reports
PIDS=()

cleanup() {
  for pid in "${PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
}
trap cleanup EXIT

SERVICE_NAME=payment-service PORT=18082 \
  python3 apps/server.py > reports/payment-local.log 2>&1 &
PIDS+=("$!")

SERVICE_NAME=inventory-service PORT=18083 \
  python3 apps/server.py > reports/inventory-local.log 2>&1 &
PIDS+=("$!")

SERVICE_NAME=order-service PORT=18081 \
  PAYMENT_URL=http://127.0.0.1:18082 \
  INVENTORY_URL=http://127.0.0.1:18083 \
  python3 apps/server.py > reports/order-local.log 2>&1 &
PIDS+=("$!")

SERVICE_NAME=api-gateway PORT=18080 \
  ORDER_URL=http://127.0.0.1:18081 \
  python3 apps/server.py > reports/gateway-local.log 2>&1 &
PIDS+=("$!")

sleep 2

echo "=== HEALTH CHECKS ==="
for port in 18080 18081 18082 18083; do
  curl --fail --silent --show-error "http://127.0.0.1:$port/health"
  echo
done

echo
echo "=== COMPLETE ORDER FLOW ==="
curl --fail --silent --show-error \
  http://127.0.0.1:18080/order \
  | python3 -m json.tool

echo
echo "=== TEST RESULT ==="
echo "LOCAL_BASELINE: PASSED"
