#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTEXT="${ISTIO_PART2_CONTEXT:-istio-part1}"
K=(kubectl --context "$CONTEXT")
mkdir -p "$ROOT/reports"

"${K[@]}" -n istio-part2 get pods -o wide > "$ROOT/reports/09-pods.log"
"${K[@]}" -n istio-part2 get deployments -o wide > "$ROOT/reports/09-deployments.log"
"${K[@]}" -n istio-part2 get services -o wide > "$ROOT/reports/09-services.log"
"${K[@]}" -n istio-part2 get endpointslices -o wide > "$ROOT/reports/09-endpointslices.log"
"${K[@]}" -n istio-part2 get gateway payment-waypoint -o yaml > "$ROOT/reports/09-waypoint.yaml"
"${K[@]}" -n istio-part2 get httproute payment-routing -o yaml > "$ROOT/reports/09-httproute.yaml"
"${K[@]}" -n istio-part2 get service payment-service -o yaml > "$ROOT/reports/09-payment-service.yaml"
"${K[@]}" -n istio-part2 logs deployment/payment-service-v1 --tail=500 > "$ROOT/reports/09-payment-v1.log"
"${K[@]}" -n istio-part2 logs deployment/payment-service-v2 --tail=500 > "$ROOT/reports/09-payment-v2.log"
"${K[@]}" -n istio-part2 logs deployment/order-service --tail=500 > "$ROOT/reports/09-order.log"
"${K[@]}" -n istio-part2 logs deployment/api-gateway --tail=500 > "$ROOT/reports/09-api-gateway.log"
"${K[@]}" -n istio-part2 logs deployment/payment-waypoint --tail=500 > "$ROOT/reports/09-waypoint-logs.log"

printf 'Evidence saved under %s/reports\n' "$ROOT"
