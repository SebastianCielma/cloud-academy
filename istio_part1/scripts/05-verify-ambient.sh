#!/usr/bin/env bash
set -euo pipefail

if [[ "$(kubectl config current-context)" != "istio-part1" ]]; then
  echo "ERROR: Wrong Kubernetes context"
  exit 1
fi

mkdir -p reports

echo "=== AMBIENT NAMESPACE ENROLLMENT ==="

kubectl apply -f manifests/ambient/01-enrollment.yaml

echo
echo "=== NAMESPACE LABELS ==="

kubectl get namespace istio-demo \
  -o jsonpath='{.metadata.name}{" ambient="}{.metadata.labels.istio\.io/dataplane-mode}{"\n"}'

echo
echo "=== RECREATE APPLICATION PODS FOR CNI ENROLLMENT ==="

for service in api-gateway order-service payment-service inventory-service; do
  kubectl rollout restart "deployment/$service" -n istio-demo
  kubectl rollout status "deployment/$service" -n istio-demo --timeout=180s
done

echo
echo "=== POD CONTAINERS: NO SIDECARS ==="

kubectl get pods -n istio-demo \
  -o custom-columns='POD:.metadata.name,CONTAINERS:.spec.containers[*].name,READY:.status.containerStatuses[*].ready'

echo
echo "=== ISTIO AMBIENT WORKLOADS ==="

istioctl ztunnel-config workloads -n istio-demo

echo
echo "=== APPLICATION FLOW AFTER ENROLLMENT ==="

kubectl exec -n istio-demo deploy/api-gateway -- \
  python -c 'import urllib.request; print(urllib.request.urlopen("http://order-service:8080/order", timeout=10).read().decode())'

echo
echo "=== ZTUNNEL LOGS ==="

kubectl logs -n istio-system daemonset/ztunnel --tail=35

echo
echo "=== AMBIENT VERIFICATION COMPLETED ==="
