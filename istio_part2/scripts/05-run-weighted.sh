#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTEXT="${ISTIO_PART2_CONTEXT:-istio-part1}"
REQUESTS="${ISTIO_PART2_REQUESTS:-1000}"
WORKERS="${ISTIO_PART2_WORKERS:-10}"
STAGE="${1:?Provide one of: 90-10, 75-25, 50-50, 100-v2, 100-v1}"

case "$STAGE" in
  90-10) ROUTE=11-traffic-90-10.yaml; V2=10 ;;
  75-25) ROUTE=12-traffic-75-25.yaml; V2=25 ;;
  50-50) ROUTE=13-traffic-50-50.yaml; V2=50 ;;
  100-v2) ROUTE=14-traffic-100-v2.yaml; V2=100 ;;
  100-v1) ROUTE=10-traffic-100-v1.yaml; V2=0 ;;
  *) printf 'Unknown stage: %s\n' "$STAGE" >&2; exit 2 ;;
esac

python3 "$ROOT/tools/run_experiment.py" \
  --route "$ROOT/manifests/routes/$ROUTE" \
  --scenario "weighted-$STAGE" \
  --out "$ROOT/reports/05-weighted-$STAGE" \
  --requests "$REQUESTS" \
  --workers "$WORKERS" \
  --expected-v2 "$V2" \
  --max-error-rate 0 \
  --context "$CONTEXT"
