#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${ISTIO_PART4_CONTEXT:-kind-istio-part4}"
NAMESPACE="istio-part4"

printf 'EXPERIMENT 05 — EGRESS CONTROL\n'
printf 'Target: httpbin.org\n'
printf 'Authorized workload: order-service\n'
printf 'Policy: GET /get only\n\n'

printf '$ kubectl get serviceentry,authorizationpolicy -n istio-egress\n'
kubectl --context "$CONTEXT" -n istio-egress get serviceentry,authorizationpolicy

printf '\n$ kubectl get gateway -n istio-egress\n'
kubectl --context "$CONTEXT" -n istio-egress get gateway

printf '\n$ kubectl exec deployment/order-service -- DNS and HTTP checks\n'

kubectl --context "$CONTEXT" -n "$NAMESPACE" \
  exec deployment/order-service -- python3 -c '
import socket
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

host = "httpbin.org"
print()
print("DNS CHECK:", host, flush=True)

try:
    addresses = sorted({
        item[4][0]
        for item in socket.getaddrinfo(host, 80)
    })
    print("DNS RESULT: RESOLVED", flush=True)
    print("ADDRESSES:", ", ".join(addresses), flush=True)
except OSError as error:
    print("DNS RESULT: FAILED", str(error), flush=True)
    sys.exit(1)

cases = [
    ("Allowed endpoint", "GET", "/get", 200),
    ("Denied method", "POST", "/post", 403),
    ("Denied path", "GET", "/headers", 403),
]

failures = 0

for label, method, path, expected in cases:
    url = f"http://{host}{path}"
    request = Request(url, method=method)
    print()
    print("TEST:", label, flush=True)
    print("REQUEST:", method, url, flush=True)

    try:
        with urlopen(request, timeout=15) as response:
            status = response.status
            body = response.read(160).decode(errors="replace")
    except HTTPError as error:
        status = error.code
        body = error.read(160).decode(errors="replace")
    except (URLError, TimeoutError, OSError) as error:
        status = 0
        body = str(error)

    print("HTTP", status, flush=True)
    print("EXPECTED: HTTP", expected, flush=True)
    print("RESPONSE:", body.replace("\n", " "), flush=True)

    if status == expected:
        print("RESULT: MATCHED", flush=True)
    else:
        print("RESULT: FAILED", flush=True)
        failures += 1

print()
print("SUMMARY:", len(cases) - failures, "of", len(cases), "HTTP checks matched", flush=True)

sys.exit(1 if failures else 0)
'
