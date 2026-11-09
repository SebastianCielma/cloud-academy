#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTEXT="${ISTIO_PART2_CONTEXT:-istio-part1}"
K=(kubectl --context "$CONTEXT")

"${K[@]}" get namespace istio-part2 --show-labels
"${K[@]}" -n istio-part2 get service payment-service --show-labels
"${K[@]}" -n istio-part2 get gateway payment-waypoint -o yaml
"${K[@]}" -n istio-part2 get httproute payment-routing -o yaml
"${K[@]}" -n istio-part2 get pods -o wide
"${K[@]}" -n istio-part2 get deployments

"${K[@]}" -n istio-part2 get httproute payment-routing -o json | python3 -c 'import json,sys; route=json.load(sys.stdin); c={x["type"]:x["status"] for p in route.get("status",{}).get("parents",[]) for x in p.get("conditions",[])}; print("HTTPRoute conditions:",c); sys.exit(0 if c.get("Accepted")=="True" and c.get("ResolvedRefs")=="True" else 1)'

"${K[@]}" -n istio-part2 get gateway payment-waypoint -o json | python3 -c 'import json,sys; gateway=json.load(sys.stdin); c={x["type"]:x["status"] for x in gateway.get("status",{}).get("conditions",[])}; print("Waypoint conditions:",c); sys.exit(0 if c.get("Programmed")=="True" else 1)'
