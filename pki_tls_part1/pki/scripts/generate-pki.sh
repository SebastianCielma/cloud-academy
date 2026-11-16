#!/usr/bin/env bash
set -euo pipefail

umask 077

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="${BASE_DIR}/config"
OUT_DIR="${BASE_DIR}/out"

ROOT_DIR="${OUT_DIR}/root"
INT_DIR="${OUT_DIR}/intermediate"
SERVERS_DIR="${OUT_DIR}/servers"

DOMAINS=(
  "api.internal.test"
  "payments.internal.test"
  "inventory.internal.test"
)

mkdir -p "${ROOT_DIR}" "${INT_DIR}" "${SERVERS_DIR}"

echo "[1/4] Generating Root CA (ECDSA P-384)"
openssl ecparam -name secp384r1 -genkey -noout -out "${ROOT_DIR}/root-ca.key"
openssl req -new -x509 \
  -key "${ROOT_DIR}/root-ca.key" \
  -out "${ROOT_DIR}/root-ca.crt" \
  -days 3650 \
  -config "${CONFIG_DIR}/root-ca.cnf"

echo "[2/4] Generating Intermediate CA (ECDSA P-384)"
openssl ecparam -name secp384r1 -genkey -noout -out "${INT_DIR}/intermediate-ca.key"
openssl req -new \
  -key "${INT_DIR}/intermediate-ca.key" \
  -out "${INT_DIR}/intermediate-ca.csr" \
  -config "${CONFIG_DIR}/intermediate-ca.cnf"

openssl x509 -req \
  -in "${INT_DIR}/intermediate-ca.csr" \
  -CA "${ROOT_DIR}/root-ca.crt" \
  -CAkey "${ROOT_DIR}/root-ca.key" \
  -CAcreateserial \
  -out "${INT_DIR}/intermediate-ca.crt" \
  -days 1095 \
  -sha384 \
  -extfile "${CONFIG_DIR}/intermediate-ca.cnf" \
  -extensions v3_intermediate_ca

rm -f "${INT_DIR}/intermediate-ca.csr"

echo "[3/4] Generating Server Certificates (ECDSA P-256)"
for domain in "${DOMAINS[@]}"; do
  DOMAIN_DIR="${SERVERS_DIR}/${domain}"
  mkdir -p "${DOMAIN_DIR}"

  export SERVER_CN="${domain}"

  openssl ecparam -name prime256v1 -genkey -noout -out "${DOMAIN_DIR}/server.key"
  openssl req -new \
    -key "${DOMAIN_DIR}/server.key" \
    -out "${DOMAIN_DIR}/server.csr" \
    -config "${CONFIG_DIR}/server.cnf"

  openssl x509 -req \
    -in "${DOMAIN_DIR}/server.csr" \
    -CA "${INT_DIR}/intermediate-ca.crt" \
    -CAkey "${INT_DIR}/intermediate-ca.key" \
    -CAcreateserial \
    -out "${DOMAIN_DIR}/server.crt" \
    -days 90 \
    -sha256 \
    -extfile "${CONFIG_DIR}/server.cnf" \
    -extensions v3_server

  cat "${DOMAIN_DIR}/server.crt" "${INT_DIR}/intermediate-ca.crt" > "${DOMAIN_DIR}/fullchain.pem"
  rm -f "${DOMAIN_DIR}/server.csr"
done

echo "[4/4] Verifying Certificate Chains"
openssl verify -CAfile "${ROOT_DIR}/root-ca.crt" "${INT_DIR}/intermediate-ca.crt"

for domain in "${DOMAINS[@]}"; do
  openssl verify \
    -CAfile "${ROOT_DIR}/root-ca.crt" \
    -untrusted "${INT_DIR}/intermediate-ca.crt" \
    "${SERVERS_DIR}/${domain}/server.crt"
done

echo "PKI generation and verification completed successfully."
