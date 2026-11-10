#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${ISTIO_PART3_CONTEXT:-kind-istio-part3}"

kubectl --context "$CONTEXT" -n istio-part3 scale deployment api-gateway order-service payment-service inventory-service --replicas=0
kubectl --context "$CONTEXT" -n istio-part3 get deployments
