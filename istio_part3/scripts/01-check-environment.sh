#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${ISTIO_PART3_CONTEXT:-kind-istio-part3}"
PROFILE="${ISTIO_PART3_PROFILE:-istio-part1}"

for binary in kubectl minikube docker python3; do
  command -v "$binary" >/dev/null
done

kubectl --context "$CONTEXT" get nodes -o wide
minikube -p "$PROFILE" status
kubectl --context "$CONTEXT" -n istio-system get deployments,daemonsets
kubectl --context "$CONTEXT" get gatewayclass istio-waypoint
kubectl --context "$CONTEXT" get crd httproutes.gateway.networking.k8s.io
python3 --version
