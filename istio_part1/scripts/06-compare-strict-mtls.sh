#!/usr/bin/env bash
set -euo pipefail

if [[ "$(kubectl config current-context)" != "istio-part1" ]]; then
  echo "ERROR: Wrong Kubernetes context"
  exit 1
fi

restore_strict() {
  echo
  echo "=== RESTORE STRICT MTLS ==="
  kubectl apply -f manifests/security/01-peer-authentication.yaml
}

trap restore_strict EXIT

echo "=== TEMPORARILY SET PERMISSIVE ==="

kubectl patch peerauthentication default \
  -n istio-demo \
  --type=merge \
  -p '{"spec":{"mtls":{"mode":"PERMISSIVE"}}}'

echo
echo "=== WAIT FOR POLICY PROPAGATION ==="
sleep 10

echo
echo "=== CREATE OUTSIDE-MESH CLIENT ==="

kubectl apply -f /tmp/istio-outside-client.yaml

kubectl wait -n default \
  --for=jsonpath='{.status.phase}'=Succeeded \
  pod/outside-mesh-client \
  --timeout=90s || true

echo
echo "=== PERMISSIVE TEST RESULT ==="

kubectl logs -n default outside-mesh-client

echo
echo "=== DELETE TEST POD ==="

kubectl delete pod outside-mesh-client \
  -n default \
  --ignore-not-found
