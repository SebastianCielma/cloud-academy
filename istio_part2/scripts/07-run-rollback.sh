#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTEXT="${ISTIO_PART2_CONTEXT:-istio-part1}"
REQUESTS="${ISTIO_PART2_REQUESTS:-1000}"
ROUTE="$ROOT/manifests/routes/12-traffic-75-25.yaml"
ROLLBACK="$ROOT/manifests/routes/16-traffic-100-v1-rollback.yaml"
mkdir -p "$ROOT/reports"

restore_routing() {
  kubectl --context "$CONTEXT" apply -f "$ROLLBACK" >/dev/null || true
}
trap restore_routing EXIT

kubectl --context "$CONTEXT" -n istio-part2 get deployments payment-service-v1 payment-service-v2 -o wide > "$ROOT/reports/07-deployments-before.log"

python3 "$ROOT/tools/run_experiment.py" --route "$ROUTE" --scenario pre-regression --out "$ROOT/reports/07-pre-regression" --requests "$REQUESTS" --expected-v2 25 --max-error-rate 0 --context "$CONTEXT"
python3 "$ROOT/tools/run_experiment.py" --route "$ROUTE" --scenario simulated-v2-regression --out "$ROOT/reports/07-regression" --requests "$REQUESTS" --header 'X-Lab-V2-Regression:true' --expected-v2 25 --min-error-rate 0.12 --max-error-rate 0.4 --context "$CONTEXT"
python3 "$ROOT/tools/run_experiment.py" --route "$ROLLBACK" --scenario rollback-to-v1 --out "$ROOT/reports/07-rollback" --requests "$REQUESTS" --header 'X-Lab-V2-Regression:true' --expect-version v1 --max-error-rate 0 --context "$CONTEXT"

kubectl --context "$CONTEXT" -n istio-part2 get deployments payment-service-v1 payment-service-v2 -o wide > "$ROOT/reports/07-deployments-after.log"
kubectl --context "$CONTEXT" -n istio-part2 get deployments payment-service-v1 payment-service-v2 -o wide
