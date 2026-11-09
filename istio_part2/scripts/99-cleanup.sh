#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${ISTIO_PART2_CONTEXT:-istio-part1}"
kubectl --context "$CONTEXT" delete namespace istio-part2 --ignore-not-found
