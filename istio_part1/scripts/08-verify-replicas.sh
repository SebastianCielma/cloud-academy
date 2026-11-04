#!/usr/bin/env bash
set -euo pipefail

if [[ "$(kubectl config current-context)" != "istio-part1" ]]; then
  echo "ERROR: Wrong Kubernetes context"
  exit 1
fi

echo "=== ORDER SERVICE REPLICAS ==="

kubectl get pods -n istio-demo \
  -l app=order-service \
  -o custom-columns='POD:.metadata.name,SERVICE_ACCOUNT:.spec.serviceAccountName,READY:.status.containerStatuses[*].ready'

echo
echo "=== TEST EACH REPLICA ==="

mapfile -t PODS < <(
  kubectl get pods -n istio-demo \
    -l app=order-service \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'
)

if [[ "${#PODS[@]}" -ne 2 ]]; then
  echo "ERROR: Expected exactly two Order Service pods"
  exit 1
fi

for POD in "${PODS[@]}"; do
  echo
  echo "Testing pod: $POD"

  kubectl exec -n istio-demo "$POD" -- \
    python -c '
import urllib.request

url = "http://payment-service:8080/payment"
response = urllib.request.urlopen(url, timeout=5)
print("ALLOW:", response.read().decode())
'
done

echo
echo "=== ZTUNNEL WORKLOADS ==="

istioctl ztunnel-config workloads -n istio-system \
  | grep -E '^NAMESPACE|^istio-demo.*order-service'

echo
echo "=== BOTH REPLICAS VERIFIED ==="
