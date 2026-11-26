#!/usr/bin/env bash
set -euo pipefail

BASE=".local/pki"
echo "| File / Location | Owner | Subject | Issuer | Serial | SAN | NotBefore | NotAfter |"
echo "| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |"

for cert in   "${BASE}/root-v1/ca.crt"   "${BASE}/root-v2/ca.crt"   "${BASE}/int-v1/ca.crt"   "${BASE}/int-v2/ca.crt"   "${BASE}/services/payment-v2.crt"   "${BASE}/services/order-v2.crt"   "${BASE}/services/inventory-v2.crt"   "${BASE}/clients/order-client-v2.crt"; do

  OWNER="platform-security"
  [[ "${cert}" == *payment* ]] && OWNER="payments-team"
  [[ "${cert}" == *order* ]] && OWNER="orders-team"
  [[ "${cert}" == *inventory* ]] && OWNER="inventory-team"

  SUBJ=$(openssl x509 -in "${cert}" -noout -subject | sed 's/subject=//')
  ISS=$(openssl x509 -in "${cert}" -noout -issuer | sed 's/issuer=//')
  SER=$(openssl x509 -in "${cert}" -noout -serial | sed 's/serial=//')
  NB=$(openssl x509 -in "${cert}" -noout -startdate | sed 's/notBefore=//')
  NA=$(openssl x509 -in "${cert}" -noout -enddate | sed 's/notAfter=//')
  SAN=$(openssl x509 -in "${cert}" -noout -ext subjectAltName 2>/dev/null | tail -n +2 | tr -d '
' | sed 's/^ *//' || echo "N/A (CA)")
  [[ -z "${SAN}" ]] && SAN="N/A (CA)"

  echo "| ${cert} | ${OWNER} | ${SUBJ} | ${ISS} | ${SER} | ${SAN} | ${NB} | ${NA} |"
done
