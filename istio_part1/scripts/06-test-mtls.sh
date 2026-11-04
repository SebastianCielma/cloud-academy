#!/usr/bin/env bash
set -euo pipefail

if [[ "$(kubectl config current-context)" != "istio-part1" ]]; then
  echo "ERROR: Wrong Kubernetes context"
  exit 1
fi

mkdir -p reports

echo "=== NAMESPACE ENROLLMENT ==="
kubectl get namespace istio-demo \
  -o jsonpath='{.metadata.name}{" ambient="}{.metadata.labels.istio\.io/dataplane-mode}{"\n"}'

echo
echo "=== WORKLOADS IN ZTUNNEL ==="
istioctl ztunnel-config workloads -n istio-system \
  | grep -E '^NAMESPACE|^istio-demo'

echo
echo "=== PEER AUTHENTICATION BEFORE STRICT ==="
kubectl get peerauthentication -A

echo
echo "=== ORDER TO PAYMENT REQUEST ==="
kubectl exec -n istio-demo deploy/order-service -- \
  python -c 'import urllib.request; print(urllib.request.urlopen("http://payment-service:8080/payment", timeout=10).read().decode())'

echo
echo "=== FULL APPLICATION FLOW ==="
kubectl exec -n istio-demo deploy/api-gateway -- \
  python -c 'import urllib.request; print(urllib.request.urlopen("http://order-service:8080/order", timeout=10).read().decode())'

echo
echo "=== ZTUNNEL METRICS ==="
kubectl exec -n istio-system daemonset/ztunnel -- \
  curl -fsS http://127.0.0.1:15020/metrics \
  | grep '^istio_tcp_connections_opened_total' \
  | grep 'istio-demo' \
  | head -20 || true

echo
echo "=== TEST COMPLETED ==="
