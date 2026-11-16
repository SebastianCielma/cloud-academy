#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${ISTIO_PART4_CONTEXT:-kind-istio-part4}"
NAMESPACE="istio-part4"

printf 'EXPERIMENT 03 — HTTP-LEVEL AUTHORIZATION\n'
printf 'Requirement: Restrict Payment Service by workload identity, HTTP method and path\n\n'

printf '$ kubectl get authorizationpolicy -n %s\n' "$NAMESPACE"
kubectl --context "$CONTEXT" -n "$NAMESPACE" get authorizationpolicy

run_tests() {
  local source="$1"

  printf '\nSOURCE: %s\n' "$source"
  printf '$ kubectl exec deployment/%s -- python3 HTTP authorization tests\n' "$source"

  kubectl --context "$CONTEXT" -n "$NAMESPACE" exec "deployment/$source" -- \
    python3 -c '
import json
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

source = sys.argv[1]
base = "http://payment-service:8080"

def check(method, path, expected, body=None):
    print(f"\n$ {method} {base}{path}", flush=True)
    data = json.dumps(body).encode() if body is not None else None
    request = Request(
        base + path,
        data=data,
        method=method,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urlopen(request, timeout=10) as response:
            status = response.status
            content = response.read().decode()
    except HTTPError as error:
        status = error.code
        content = error.read().decode()
    except URLError as error:
        print(f"TRANSPORT ERROR: {error.reason}", flush=True)
        sys.exit(1)

    print(f"HTTP {status}", flush=True)
    print(content, flush=True)
    print(f"Expected: HTTP {expected}", flush=True)

    if status != expected:
        print("RESULT: FAILED", flush=True)
        sys.exit(1)

    print("RESULT: MATCHED", flush=True)
    return content

if source == "order-service":
    check("GET", "/health", 200)
    created = check("POST", "/payments", 201, {"amount": 125.50})
    payment_id = json.loads(created)["payment_id"]
    check("GET", f"/payments/{payment_id}", 200)
    check("GET", "/version", 403)
    check("POST", "/health", 403, {"amount": 1})
else:
    check("GET", "/health", 403)
' "$source"
}

run_tests order-service
run_tests inventory-service
run_tests unknown-client

printf '\nEXPERIMENT RESULT: ALL 7 CHECKS MATCHED EXPECTATIONS\n'
