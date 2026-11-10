#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTEXT="${ISTIO_PART3_CONTEXT:-kind-istio-part3}"

kubectl --context "$CONTEXT" apply -f "$ROOT/manifests/ambient/00-namespace.yaml"
kubectl --context "$CONTEXT" -n istio-part3 apply -f "$ROOT/manifests/base/"
kubectl --context "$CONTEXT" apply -f "$ROOT/manifests/ambient/01-waypoint.yaml"

for service in api-gateway order-service payment-service inventory-service; do
  kubectl --context "$CONTEXT" -n istio-part3 rollout status "deployment/$service" --timeout=180s
done

kubectl --context "$CONTEXT" -n istio-part3 wait --for=condition=Programmed gateways.gateway.networking.k8s.io/waypoint --timeout=180s
kubectl --context "$CONTEXT" -n istio-part3 get deployments,services,gateways.gateway.networking.k8s.io
