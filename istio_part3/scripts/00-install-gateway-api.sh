#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${ISTIO_PART3_CONTEXT:-kind-istio-part3}"

if kubectl --context "$CONTEXT" get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1; then
  printf 'Gateway API CRDs are already installed.\n'
else
  kubectl --context "$CONTEXT" apply --server-side \
    -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.4.1/experimental-install.yaml
fi

kubectl --context "$CONTEXT" get crd gateways.gateway.networking.k8s.io httproutes.gateway.networking.k8s.io
