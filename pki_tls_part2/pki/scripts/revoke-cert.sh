#!/usr/bin/env bash
set -euo pipefail
umask 077

TARGET="${1:-inventory-service}"
SERIAL="${2:-}"
OUT_DIR="/work/pki/out"
CFG_DIR="/work/pki/config"

if [[ -n "${SERIAL}" ]]; then
  CERT_PATH="${OUT_DIR}/clients/${TARGET}/releases/${SERIAL}/${TARGET}.crt"
else
  CERT_PATH="${OUT_DIR}/clients/${TARGET}/current/${TARGET}.crt"
fi

if [[ ! -f "${CERT_PATH}" ]]; then
  echo "Certificate not found: ${CERT_PATH}" >&2
  exit 1
fi

echo "Revoking client certificate: ${CERT_PATH}"
openssl ca -batch -config "${CFG_DIR}/intermediate-ca.cnf" -revoke "${CERT_PATH}" >/dev/null 2>&1

echo "Regenerating signed CRL bundle"
openssl ca -batch -config "${CFG_DIR}/intermediate-ca.cnf" -gencrl \
  -crlexts crl_ext -out "${OUT_DIR}/crl/intermediate.crl.pem" >/dev/null 2>&1
cat "${OUT_DIR}/crl/intermediate.crl.pem" "${OUT_DIR}/crl/root.crl.pem" >"${OUT_DIR}/crl/crl-bundle.pem"

echo "CA database status (R = Revoked, V = Valid):"
cat "${OUT_DIR}/intermediate/db/index.txt"
