#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${ISTIO_PART2_CONTEXT:-istio-part1}"
GATEWAY_API_VERSION="${ISTIO_PART2_GATEWAY_API_VERSION:-v1.4.1}"

if ! kubectl --context "$CONTEXT" get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1; then
  kubectl --context "$CONTEXT" apply --server-side -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml"
fi

kubectl --context "$CONTEXT" get crd gateways.gateway.networking.k8s.io httproutes.gateway.networking.k8s.io
kubectl --context "$CONTEXT" get gatewayclass istio-waypoint
