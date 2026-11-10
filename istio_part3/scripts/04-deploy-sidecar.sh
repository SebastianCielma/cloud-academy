#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTEXT="${ISTIO_PART3_CONTEXT:-kind-istio-part3}"

kubectl --context "$CONTEXT" apply -f "$ROOT/manifests/sidecar/00-namespace.yaml"
kubectl --context "$CONTEXT" apply -f "$ROOT/manifests/sidecar/01-serviceaccounts.yaml"
kubectl --context "$CONTEXT" apply -f "$ROOT/manifests/sidecar/02-deployments.yaml"
kubectl --context "$CONTEXT" apply -f "$ROOT/manifests/sidecar/03-services.yaml"

for service in order-service payment-service inventory-service; do
  kubectl --context "$CONTEXT" -n istio-part3-sidecar rollout status "deployment/$service" --timeout=240s
done

kubectl --context "$CONTEXT" -n istio-part3-sidecar get pods -o json | python3 -c '
import json
import sys
items = json.load(sys.stdin)["items"]
if len(items) != 3 or any(len(item["spec"]["containers"]) != 2 for item in items):
    raise SystemExit("Expected three application pods with two containers each: application and istio-proxy")
print("All three sidecar workloads have istio-proxy")
'
