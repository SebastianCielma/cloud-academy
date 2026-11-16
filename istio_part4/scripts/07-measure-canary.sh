#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${ISTIO_PART4_CONTEXT:-kind-istio-part4}"
NAMESPACE="istio-part4"
SAMPLES="${1:-200}"
PHASE="${2:-baseline}"

printf 'EXPERIMENT 07 — CANARY TRAFFIC MEASUREMENT\n'
printf 'Phase: %s\n' "$PHASE"
printf 'Requests: %s\n' "$SAMPLES"
printf 'Endpoint: POST /payments\n\n'

printf 'CURRENT ROUTING CONFIGURATION\n'
kubectl --context "$CONTEXT" -n "$NAMESPACE" get httproute payment-canary \
  -o jsonpath='{range .spec.rules[*].backendRefs[*]}{.name}{" weight="}{.weight}{"\n"}{end}'

printf '\nACTUAL HTTP MEASUREMENTS\n'

kubectl --context "$CONTEXT" -n "$NAMESPACE" \
  exec deployment/order-service -- \
  python3 -c '
import json
import sys
import time
from collections import Counter
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

samples = int(sys.argv[1])
counts = Counter()
start = time.perf_counter()

for i in range(samples):
    payload = json.dumps({"amount": 10 + i}).encode()
    request = Request(
        "http://payment-service:8080/payments",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urlopen(request, timeout=5) as response:
            status = response.status
            body = json.loads(response.read())
            version = body.get("version", "unknown")
    except HTTPError as error:
        status = error.code
        version = "error"
    except (URLError, TimeoutError, OSError):
        status = 0
        version = "error"

    counts[(status, version)] += 1

    if (i + 1) % 50 == 0:
        print(f"Progress: {i + 1}/{samples}", flush=True)

elapsed = time.perf_counter() - start
v1 = counts[(201, "v1")]
v2 = counts[(201, "v2")]
success = v1 + v2
failures = samples - success

print("\nMEASURED RESULTS", flush=True)
print(f"HTTP 201 v1: {v1}", flush=True)
print(f"HTTP 201 v2: {v2}", flush=True)
print(f"Other responses: {failures}", flush=True)
print(f"Success rate: {success / samples * 100:.2f}%", flush=True)
print(f"v1 traffic share: {v1 / samples * 100:.2f}%", flush=True)
print(f"v2 traffic share: {v2 / samples * 100:.2f}%", flush=True)
print(f"Elapsed: {elapsed:.2f}s", flush=True)
print(f"Configured target: v1=90%, v2=10%", flush=True)

if failures:
    print("\nERROR BREAKDOWN", flush=True)
    for (status, version), count in sorted(counts.items()):
        if status != 201 or version not in ("v1", "v2"):
            print(f"HTTP {status}, version={version}: {count}", flush=True)

sys.exit(0 if failures == 0 else 1)
' "$SAMPLES"
