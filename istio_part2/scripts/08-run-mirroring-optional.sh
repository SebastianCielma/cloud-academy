#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTEXT="${ISTIO_PART2_CONTEXT:-istio-part1}"
REQUESTS="${ISTIO_PART2_MIRROR_REQUESTS:-120}"

python3 "$ROOT/tools/verify_mirroring.py" \
  --route "$ROOT/manifests/routes/17-mirroring-optional.yaml" \
  --out "$ROOT/reports/08-optional-mirroring" \
  --requests "$REQUESTS" \
  --context "$CONTEXT"
