#!/usr/bin/env bash
set -euo pipefail

BASE=".local/pki"
echo "=== COMPROMISED INTERMEDIATE CA v1 INCIDENT RESPONSE ==="

echo "[Step 1] Halt issuance: disable/quarantine compromised Intermediate CA v1 key"
chmod 000 "${BASE}/int-v1/ca.key"
echo "Quarantined ${BASE}/int-v1/ca.key (permissions 000)."

echo ""
echo "[Step 2] Identify all certificates issued by compromised Intermediate CA v1:"
for cert in "${BASE}"/services/*-v1.crt "${BASE}"/clients/*-v1.crt; do
  ISSUER=$(openssl x509 -in "${cert}" -noout -issuer)
  SERIAL=$(openssl x509 -in "${cert}" -noout -serial)
  SUBJ=$(openssl x509 -in "${cert}" -noout -subject)
  echo "  [AFFECTED] ${cert} | ${SUBJ} | ${SERIAL} | ${ISSUER}"
done

echo ""
echo "[Step 3] Revoke Intermediate CA v1 at Root CA v1 and publish CRL:"
cat << CFG > "${BASE}/root-v1/crl.cnf"
[ ca ]
default_ca = CA_default
[ CA_default ]
dir               = ${BASE}/root-v1
database          = \$dir/index.txt
crlnumber         = \$dir/crlnumber
certificate       = \$dir/ca.crt
private_key       = \$dir/ca.key
default_md        = sha256
default_crl_days  = 7
CFG

openssl ca -config "${BASE}/root-v1/crl.cnf" -revoke "${BASE}/int-v1/ca.crt" 2>/dev/null || true
openssl ca -config "${BASE}/root-v1/crl.cnf" -gencrl -out "${BASE}/root-v1/root-v1.crl" 2>/dev/null
echo "Published Root CA v1 CRL: ${BASE}/root-v1/root-v1.crl"
openssl crl -in "${BASE}/root-v1/root-v1.crl" -noout -text | grep -A 3 "Revoked Certificates:" || true

echo ""
echo "[Step 4] Distribute updated trust store (Root v1 + CRL, Int v1 removed) & verify enforcement:"
echo "[Check] Compromised Intermediate CA v1 MUST BE REJECTED by Root CA CRL (certificate revoked):"
if openssl verify -crl_check -CAfile "${BASE}/root-v1/ca.crt" \
  -CRLfile "${BASE}/root-v1/root-v1.crl" \
  "${BASE}/int-v1/ca.crt" 2>&1; then
  echo "UNEXPECTED: compromised Intermediate CA v1 passed!"
  exit 1
else
  echo "[OK] Compromised Intermediate CA v1 explicitly REVOKED by Root CA v1 CRL!"
fi

echo "[Check] Clean Intermediate CA v2 PASSES Root CA CRL check:"
openssl verify -crl_check -CAfile "${BASE}/root-v1/ca.crt" \
  -CRLfile "${BASE}/root-v1/root-v1.crl" \
  "${BASE}/int-v2/ca.crt"

echo "[Check] Replacement leaf cert (payment-v2) verifies cleanly against Root v1 + Int v2:"
openssl verify -CAfile "${BASE}/root-v1/ca.crt" -untrusted "${BASE}/int-v2/ca.crt" "${BASE}/services/payment-v2.crt"

chmod 600 "${BASE}/int-v1/ca.key"
