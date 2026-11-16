from pathlib import Path
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
TOKEN_DIR = ROOT / ".local-jwt"
CONTEXT = "kind-istio-part4"
NAMESPACE = "istio-part4"

REMOTE_TEST = """
import json
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

tokens = json.loads(sys.stdin.read())
base = "http://payment-service:8080"

def call(method, path, token=None, body=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token

    data = json.dumps(body).encode() if body is not None else None
    request = Request(base + path, data=data, headers=headers, method=method)

    try:
        with urlopen(request, timeout=10) as response:
            return response.status, response.read().decode()
    except HTTPError as error:
        return error.code, error.read().decode()
    except URLError as error:
        return 0, str(error.reason)

status, body = call("POST", "/payments", body={"amount": 125.50})
print("SETUP: POST /payments")
print("HTTP", status)

if status != 201:
    print(body)
    sys.exit(1)

payment_id = json.loads(body)["payment_id"]
path = "/payments/" + payment_id

cases = [
    ("Valid JWT", tokens["valid"], 200),
    ("Invalid signature", tokens["invalid-signature"], 401),
    ("Expired JWT", tokens["expired"], 401),
    ("Missing JWT", None, 403),
    ("Invalid role claim", tokens["invalid-claims"], 403),
]

failures = 0

for name, token, expected in cases:
    status, body = call("GET", path, token=token)

    print()
    print("TEST:", name)
    print("REQUEST: GET /payments/{id}")
    print("HTTP", status)
    print("EXPECTED: HTTP", expected)
    print("RESPONSE:", body)
    print("RESULT:", "MATCHED" if status == expected else "FAILED")

    if status != expected:
        failures += 1

status, body = call("GET", "/health")
print()
print("REGRESSION CHECK: GET /health without JWT")
print("HTTP", status)
print("EXPECTED: HTTP 200")
print("RESULT:", "MATCHED" if status == 200 else "FAILED")

if status != 200:
    failures += 1

print()
print("SUMMARY:", 6 - failures, "of 6 checks matched")
sys.exit(1 if failures else 0)
"""

tokens = {
    name: (TOKEN_DIR / f"{name}.token").read_text().strip()
    for name in ("valid", "invalid-signature", "expired", "invalid-claims")
}

print("EXPERIMENT 04 — JWT AUTHENTICATION", flush=True)
print("Workload identity: istio-part4/order-service", flush=True)
print("Endpoint: GET /payments/{id}", flush=True)
print("JWT issuer: https://issuer.istio-part4.local", flush=True)
print("Required role: payment-reader", flush=True)
print("Tokens: not displayed", flush=True)
print(flush=True)

command = [
    "kubectl", "--context", CONTEXT,
    "-n", NAMESPACE,
    "exec", "-i", "deployment/order-service",
    "--", "python3", "-c", REMOTE_TEST,
]

result = subprocess.run(
    command,
    input=json.dumps(tokens),
    text=True,
    check=False,
)

sys.exit(result.returncode)
