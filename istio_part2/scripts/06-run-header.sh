#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTEXT="${ISTIO_PART2_CONTEXT:-istio-part1}"
REQUESTS="${ISTIO_PART2_HEADER_REQUESTS:-150}"
ROUTE="$ROOT/manifests/routes/15-header-based.yaml"

python3 "$ROOT/tools/run_experiment.py" --route "$ROUTE" --scenario no-release-header --out "$ROOT/reports/06-header-default" --requests "$REQUESTS" --expect-version v1 --max-error-rate 0 --context "$CONTEXT"
python3 "$ROOT/tools/run_experiment.py" --route "$ROUTE" --scenario beta-release-header --out "$ROOT/reports/06-header-beta" --requests "$REQUESTS" --header 'X-Release-Channel:beta' --expect-version v2 --max-error-rate 0 --context "$CONTEXT"
python3 "$ROOT/tools/run_experiment.py" --route "$ROUTE" --scenario stable-release-header --out "$ROOT/reports/06-header-stable" --requests "$REQUESTS" --header 'X-Release-Channel:stable' --expect-version v1 --max-error-rate 0 --context "$CONTEXT"
