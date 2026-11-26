#!/usr/bin/env bash
set -euo pipefail

BASE=".local/pki"
TS="${BASE}/troubleshoot"
mkdir -p "${TS}"

echo "================================================================"
echo "  CERTIFICATE TROUBLESHOOTING LAB (8 CASES: DIAGNOSE -> FIX)"
echo "================================================================"

# --- CASE 1: EXPIRED CERTIFICATE ---
echo ""
echo "[CASE 1] Expired Certificate"
cat << CFG > "${TS}/exp-ca.cnf"
[ ca ]
default_ca = CA_default
[ CA_default ]
dir               = ${BASE}/int-v2
new_certs_dir     = \$dir/newcerts
database          = \$dir/index.txt
serial            = \$dir/serial
certificate       = \$dir/ca.crt
private_key       = \$dir/ca.key
default_md        = sha256
policy            = policy_loose
unique_subject    = no
[ policy_loose ]
commonName        = supplied
CFG
openssl genrsa -out "${TS}/expired.key" 2048 2>/dev/null
openssl req -new -key "${TS}/expired.key" -subj "/CN=expired.internal.test" -out "${TS}/expired.csr"
echo "unique_subject = no" > "${BASE}/int-v2/index.txt.attr"
openssl ca -batch -config "${TS}/exp-ca.cnf" -startdate 20200101000000Z -enddate 20200102000000Z   -notext -in "${TS}/expired.csr" -out "${TS}/expired.crt" 2>/dev/null
echo "  Diagnosis:"
openssl verify -CAfile "${BASE}/root-v1/ca.crt" -untrusted "${BASE}/int-v2/ca.crt" "${TS}/expired.crt" 2>&1 || true
echo "  Fix: Re-issue certificate with valid notBefore/notAfter window ->"
openssl verify -CAfile "${BASE}/root-v1/ca.crt" -untrusted "${BASE}/int-v2/ca.crt" "${BASE}/services/order-v2.crt"

# --- CASE 2: WRONG SAN ---
echo ""
echo "[CASE 2] Wrong SAN (hostname mismatch)"
echo "  Diagnosis: Connecting to wrong-host.internal.test against order.internal.test cert:"
curl -sS --cacert "${BASE}/root-v1/ca.crt" --resolve wrong-host.internal.test:8442:127.0.0.1   https://wrong-host.internal.test:8442/ 2>&1 || true
echo "  Fix: Use matching SAN (DNS:order.internal.test) ->"
curl -sS --cacert "${BASE}/root-v1/ca.crt" --resolve order.internal.test:8442:127.0.0.1   https://order.internal.test:8442/
echo ""

# --- CASE 3: INCOMPLETE CHAIN ---
echo ""
echo "[CASE 3] Incomplete Chain (missing Intermediate CA)"
echo "  Diagnosis: Verifying leaf cert against Root CA v1 WITHOUT intermediate cert:"
openssl verify -CAfile "${BASE}/root-v1/ca.crt" "${BASE}/services/order-v2.crt" 2>&1 || true
echo "  Fix: Provide fullchain (leaf + intermediate CA v2) ->"
openssl verify -CAfile "${BASE}/root-v1/ca.crt" -untrusted "${BASE}/int-v2/ca.crt" "${BASE}/services/order-v2.crt"

# --- CASE 4: UNKNOWN CA ---
echo ""
echo "[CASE 4] Unknown CA (untrusted self-signed / foreign CA)"
openssl req -x509 -newkey rsa:2048 -nodes -keyout "${TS}/rogue.key" -out "${TS}/rogue.crt"   -days 10 -subj "/CN=rogue.internal.test" 2>/dev/null
echo "  Diagnosis: Verifying rogue cert against corporate Root CA v1:"
openssl verify -CAfile "${BASE}/root-v1/ca.crt" "${TS}/rogue.crt" 2>&1 || true
echo "  Fix: Replace with certificate signed by trusted Intermediate CA v2 ->"
openssl verify -CAfile "${BASE}/root-v1/ca.crt" -untrusted "${BASE}/int-v2/ca.crt" "${BASE}/services/inventory-v2.crt"

# --- CASE 5: WRONG EKU ---
echo ""
echo "[CASE 5] Wrong EKU (clientAuth cert used as sslserver)"
echo "  Diagnosis: Checking order-client-v2.crt (EKU=clientAuth) for sslserver purpose:"
openssl verify -purpose sslserver -CAfile "${BASE}/root-v1/ca.crt" -untrusted "${BASE}/int-v2/ca.crt"   "${BASE}/clients/order-client-v2.crt" 2>&1 || true
echo "  Fix: Use certificate with EKU=serverAuth (order-v2.crt) ->"
openssl verify -purpose sslserver -CAfile "${BASE}/root-v1/ca.crt" -untrusted "${BASE}/int-v2/ca.crt"   "${BASE}/services/order-v2.crt"

# --- CASE 6: PRIVATE KEY MISMATCH ---
echo ""
echo "[CASE 6] Private Key Mismatch"
CERT_PUB=$(openssl x509 -in "${BASE}/services/order-v2.crt" -noout -pubkey | openssl sha256)
WRONG_KEY_PUB=$(openssl pkey -in "${BASE}/services/payment-v2.key" -pubout | openssl sha256)
RIGHT_KEY_PUB=$(openssl pkey -in "${BASE}/services/order-v2.key" -pubout | openssl sha256)
echo "  Diagnosis: order-v2.crt pubkey (${CERT_PUB}) != payment-v2.key pubkey (${WRONG_KEY_PUB}) -> MISMATCH"
echo "  Fix: Pair order-v2.crt with order-v2.key (${RIGHT_KEY_PUB}) -> MATCH VERIFIED"

# --- CASE 7: PROTOCOL MISMATCH ---
echo ""
echo "[CASE 7] Protocol Mismatch (client forces TLS 1.1 against TLS 1.2/1.3 server)"
echo "  Diagnosis:"
curl -sS --tls-max 1.1 --cacert "${BASE}/root-v1/ca.crt" --resolve order.internal.test:8442:127.0.0.1   https://order.internal.test:8442/ 2>&1 || true
echo "  Fix: Negotiate TLSv1.2 / TLSv1.3 ->"
curl -sS --tlsv1.2 --cacert "${BASE}/root-v1/ca.crt" --resolve order.internal.test:8442:127.0.0.1   https://order.internal.test:8442/
echo ""

# --- CASE 8: WRONG TRUST STORE ---
echo ""
echo "[CASE 8] Wrong Trust Store (client trusts Root CA v2 instead of Root CA v1)"
echo "  Diagnosis:"
curl -sS --cacert "${BASE}/root-v2/ca.crt" --resolve order.internal.test:8442:127.0.0.1   https://order.internal.test:8442/ 2>&1 || true
echo "  Fix: Configure client with correct trust store (Root CA v1) ->"
curl -sS --cacert "${BASE}/root-v1/ca.crt" --resolve order.internal.test:8442:127.0.0.1   https://order.internal.test:8442/
echo ""
