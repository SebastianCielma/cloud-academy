#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTEXT="${ISTIO_PART3_CONTEXT:-kind-istio-part3}"

mkdir -p "$ROOT/reports"
kubectl --context "$CONTEXT" -n istio-part3 get pods,deployments,services,gateways.gateway.networking.k8s.io,httproutes.gateway.networking.k8s.io,destinationrules.networking.istio.io -o wide > "$ROOT/reports/09-ambient-resources.log"
kubectl --context "$CONTEXT" -n istio-part3 get events --sort-by=.metadata.creationTimestamp > "$ROOT/reports/10-ambient-events.log"

for service in api-gateway order-service payment-service inventory-service; do
  kubectl --context "$CONTEXT" -n istio-part3 logs "deployment/$service" --tail=500 > "$ROOT/reports/11-$service.log"
done

if kubectl --context "$CONTEXT" get namespace istio-part3-sidecar >/dev/null 2>&1; then
  kubectl --context "$CONTEXT" -n istio-part3-sidecar get pods,deployments,services,virtualservices,destinationrules -o wide > "$ROOT/reports/12-sidecar-resources.log"
  for service in order-service payment-service inventory-service; do
    kubectl --context "$CONTEXT" -n istio-part3-sidecar logs "deployment/$service" -c "$service" --tail=500 > "$ROOT/reports/13-$service-sidecar-app.log"
    kubectl --context "$CONTEXT" -n istio-part3-sidecar logs "deployment/$service" -c istio-proxy --tail=500 > "$ROOT/reports/14-$service-proxy.log"
  done
fi
