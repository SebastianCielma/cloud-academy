#!/usr/bin/env bash
set -euo pipefail
CONTEXT="${ISTIO_PART4_CONTEXT:-kind-istio-part4}"
NAMESPACE=istio-part4
probe() {
  local source="$1"
  local url="$2"
  printf '\n$ kubectl exec deployment/%s -- HTTP GET %s\n' "$source" "$url"
  kubectl --context "$CONTEXT" -n "$NAMESPACE" exec "deployment/$source" -- python3 -c '
import sys
from urllib.error import HTTPError, URLError
from urllib.request import urlopen
try:
    with urlopen(sys.argv[1], timeout=5) as response:
        print("HTTP", response.status)
        print(response.read().decode())
except HTTPError as error:
    print("HTTP", error.code)
    print(error.read().decode())
except URLError as error:
    print("NETWORK ERROR", str(error.reason))
    raise SystemExit(1)
' "$url"
}
printf 'BASELINE — No AuthorizationPolicy applied\n'
probe api-gateway http://order-service:8080/order
probe order-service http://payment-service:8080/health
probe inventory-service http://payment-service:8080/health
probe unknown-client http://payment-service:8080/health
