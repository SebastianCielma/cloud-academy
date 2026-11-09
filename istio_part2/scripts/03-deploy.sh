#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTEXT="${ISTIO_PART2_CONTEXT:-istio-part1}"
K=(kubectl --context "$CONTEXT")

"${K[@]}" apply -f "$ROOT/manifests/base/00-namespace.yaml"
"${K[@]}" apply -f "$ROOT/manifests/base/01-serviceaccounts.yaml"
"${K[@]}" apply -f "$ROOT/manifests/base/02-deployments.yaml"
"${K[@]}" apply -f "$ROOT/manifests/base/03-services.yaml"
"${K[@]}" -n istio-part2 rollout status deployment/api-gateway --timeout=180s
"${K[@]}" -n istio-part2 rollout status deployment/order-service --timeout=180s
"${K[@]}" -n istio-part2 rollout status deployment/inventory-service --timeout=180s
"${K[@]}" -n istio-part2 rollout status deployment/payment-service-v1 --timeout=180s
"${K[@]}" -n istio-part2 rollout status deployment/payment-service-v2 --timeout=180s
"${K[@]}" apply -f "$ROOT/manifests/ambient/00-payment-waypoint.yaml"
"${K[@]}" -n istio-part2 wait --for=condition=Programmed gateway/payment-waypoint --timeout=180s
python3 "$ROOT/tools/run_experiment.py" --route "$ROOT/manifests/routes/10-traffic-100-v1.yaml" --scenario initial-v1-baseline --out "$ROOT/reports/03-initial-v1-baseline" --requests 40 --expect-version v1 --max-error-rate 0 --context "$CONTEXT"
"${K[@]}" -n istio-part2 get deployments,services,gateways,httproutes
