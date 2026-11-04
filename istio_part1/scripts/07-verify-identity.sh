#!/usr/bin/env bash
set -euo pipefail

if [[ "$(kubectl config current-context)" != "istio-part1" ]]; then
  echo "ERROR: Wrong Kubernetes context"
  exit 1
fi

echo "=== AUTHORIZATION POLICY STATUS ==="
kubectl get authorizationpolicy payment-only-from-order \
  -n istio-demo \
  -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.message}{"\n"}{end}'

echo
echo "=== ALLOWED: ORDER TO PAYMENT ==="
kubectl exec -n istio-demo deploy/order-service -- \
  python -c '
import urllib.request
url = "http://payment-service:8080/payment"
response = urllib.request.urlopen(url, timeout=5)
print("ALLOW:", response.read().decode())
'

echo
echo "=== DENIED: INVENTORY TO PAYMENT ==="
kubectl exec -n istio-demo deploy/inventory-service -- \
  python -c '
import urllib.request
import sys

url = "http://payment-service:8080/payment"

try:
    response = urllib.request.urlopen(url, timeout=5)
    print("FAIL: unexpected access:", response.read().decode())
    sys.exit(1)
except Exception as exc:
    print("DENY:", type(exc).__name__, str(exc))
'

echo
echo "=== FULL APPLICATION FLOW ==="
kubectl exec -n istio-demo deploy/api-gateway -- \
  python -c '
import urllib.request
url = "http://order-service:8080/order"
response = urllib.request.urlopen(url, timeout=10)
print("FLOW:", response.read().decode())
'

echo
echo "=== TEST COMPLETED ==="
