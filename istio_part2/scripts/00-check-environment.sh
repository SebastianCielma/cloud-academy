#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${ISTIO_PART2_CONTEXT:-istio-part1}"
PROFILE="${ISTIO_PART2_PROFILE:-istio-part1}"

for binary in kubectl minikube docker python3; do
  command -v "$binary" >/dev/null || { printf 'Required command not found: %s\n' "$binary" >&2; exit 1; }
done

kubectl config get-contexts "$CONTEXT"
minikube -p "$PROFILE" status
kubectl --context "$CONTEXT" -n istio-system get deployment istiod
kubectl --context "$CONTEXT" -n istio-system get daemonset istio-cni-node ztunnel
kubectl --context "$CONTEXT" get gatewayclass istio-waypoint
kubectl --context "$CONTEXT" get crd gateways.gateway.networking.k8s.io httproutes.gateway.networking.k8s.io
