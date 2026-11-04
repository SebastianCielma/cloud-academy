#!/usr/bin/env bash
set -euo pipefail

EXPECTED_CONTEXT="istio-part1"
CURRENT_CONTEXT="$(kubectl config current-context)"

if [[ "$CURRENT_CONTEXT" != "$EXPECTED_CONTEXT" ]]; then
  echo "ERROR: Expected context $EXPECTED_CONTEXT, got $CURRENT_CONTEXT"
  exit 1
fi

echo "=== KUBERNETES NODE ==="
kubectl get nodes

echo
echo "=== INSTALL ISTIO AMBIENT ==="

istioctl install \
  --set profile=ambient \
  --set values.global.platform=minikube \
  --set values.cni.cniNetnsDir=/var/run/netns \
  --skip-confirmation

echo
echo "=== ISTIO COMPONENTS ==="
kubectl get deployments,daemonsets,pods -n istio-system

echo
echo "=== INSTALLATION COMPLETED ==="
