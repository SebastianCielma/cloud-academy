#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTEXT="${ISTIO_PART4_CONTEXT:-kind-istio-part4}"
cd "$ROOT"

docker build -t istio-part4/app:v1 -f apps/Dockerfile apps
kind load docker-image istio-part4/app:v1 --name istio-part4
kubectl --context "$CONTEXT" apply -f manifests/base/00-namespace.yaml
kubectl --context "$CONTEXT" apply -f manifests/base/01-serviceaccounts.yaml
kubectl --context "$CONTEXT" apply -f manifests/base/02-deployments.yaml
kubectl --context "$CONTEXT" apply -f manifests/base/03-services.yaml
kubectl --context "$CONTEXT" apply -f manifests/ambient/00-payment-waypoint.yaml
for service in api-gateway order-service payment-service inventory-service unknown-client; do
  kubectl --context "$CONTEXT" -n istio-part4 rollout status "deployment/$service" --timeout=180s
done
kubectl --context "$CONTEXT" -n istio-part4 wait --for=condition=Programmed gateway/payment-waypoint --timeout=180s
kubectl --context "$CONTEXT" -n istio-part4 get deployments
kubectl --context "$CONTEXT" -n istio-part4 get gateway
