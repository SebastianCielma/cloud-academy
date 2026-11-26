#!/usr/bin/env bash
set -euo pipefail

BASE=".local/pki"
echo "=== 1. INTERMEDIATE CA ROTATION (v1 -> v2 under same Root CA v1) ==="
echo "[Check] Verify Intermediate v2 chain against Root CA v1:"
openssl verify -CAfile "${BASE}/root-v1/ca.crt" "${BASE}/int-v2/ca.crt"
echo "[Check] Verify new payment-v2 leaf cert chain (leaf -> int-v2 -> root-v1):"
openssl verify -CAfile "${BASE}/root-v1/ca.crt" -untrusted "${BASE}/int-v2/ca.crt" "${BASE}/services/payment-v2.crt"

echo ""
echo "=== 2. WRONG TRUST MIGRATION ORDER (CA v2 used BEFORE client trust store update) ==="
echo "[Sim] Client pinned only to Intermediate CA v1 verifies server cert from Intermediate CA v2:"
if openssl verify -CAfile "${BASE}/trust/int-v1-only.pem" -partial_chain "${BASE}/services/payment-v2.crt" 2>&1; then
  echo "UNEXPECTED: should have failed"
  exit 1
else
  echo "[EXPECTED FAILURE] Verification failed because client trust store only trusts Intermediate v1!"
fi

echo ""
echo "=== 3. CORRECT TRUST MIGRATION ORDER (Zero-Downtime) ==="
echo "Step A: Distribute dual trust store (Root v1 + Int v1 + Int v2) to clients"
echo "Step B: Issue v2 certs for services & clients"
echo "Step C: Swap service certificates to v2 (live reload without downtime)"
python3 -c '
for f in ["infra/nginx/payment.conf", "infra/nginx/order.conf", "infra/nginx/inventory.conf"]:
    txt = open(f).read().replace("-v1", "-v2").replace("\"v1\"", "\"v2\"")
    open(f, "w").write(txt)
'
docker exec pki4-payment nginx -s reload
docker exec pki4-order nginx -s reload
docker exec pki4-inventory nginx -s reload
sleep 1

echo "Step D: Validate TLS & mTLS on v2 (both v1 & v2 clients accepted during migration window):"
curl -sS --cacert "${BASE}/trust/dual-int-bundle.pem"   --cert "${BASE}/clients/order-client-v2-fullchain.crt"   --key "${BASE}/clients/order-client-v2.key"   --resolve payment.internal.test:8441:127.0.0.1   https://payment.internal.test:8441/
echo ""
curl -sS --cacert "${BASE}/trust/dual-int-bundle.pem"   --resolve order.internal.test:8442:127.0.0.1   https://order.internal.test:8442/
echo ""

echo "Step E: Verify chain served live by payment-service is now Intermediate CA v2:"
openssl s_client -connect 127.0.0.1:8441 -servername payment.internal.test   -CAfile "${BASE}/trust/root-v1.pem"   -cert "${BASE}/clients/order-client-v2-fullchain.crt"   -key "${BASE}/clients/order-client-v2.key" </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer

echo ""
echo "=== 4. ROOT CA ROTATION (Dual-Root Temporary Trust) ==="
# Issue a test server cert under Root CA v2
openssl genrsa -out "${BASE}/services/rootv2-test.key" 2048 2>/dev/null
openssl req -new -key "${BASE}/services/rootv2-test.key" -subj "/C=PL/O=CloudAcademy/CN=rootv2.internal.test" -out "${BASE}/services/rootv2-test.csr"
openssl x509 -req -in "${BASE}/services/rootv2-test.csr"   -CA "${BASE}/root-v2/ca.crt" -CAkey "${BASE}/root-v2/ca.key" -CAcreateserial   -out "${BASE}/services/rootv2-test.crt" -days 30 -sha256 2>/dev/null

echo "[Check] Single Root v1 bundle FAILS to verify Root v2 cert:"
openssl verify -CAfile "${BASE}/root-v1/ca.crt" "${BASE}/services/rootv2-test.crt" 2>&1 || true

echo "[Check] Dual-Root bundle (Root v1 + Root v2) verifies BOTH Root v1 (via int-v2) AND Root v2 certs:"
openssl verify -CAfile "${BASE}/trust/dual-root-bundle.pem" -untrusted "${BASE}/int-v2/ca.crt" "${BASE}/services/payment-v2.crt"
openssl verify -CAfile "${BASE}/trust/dual-root-bundle.pem" "${BASE}/services/rootv2-test.crt"
