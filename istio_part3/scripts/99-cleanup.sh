#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${ISTIO_PART3_CONTEXT:-kind-istio-part3}"

kubectl --context "$CONTEXT" delete namespace istio-part3 istio-part3-sidecar --ignore-not-found
