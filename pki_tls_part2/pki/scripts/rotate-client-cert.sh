#!/usr/bin/env bash
set -euo pipefail
umask 077

TARGET="${1:-order-service}"
OUT_DIR="/work/pki/out"
CFG_DIR="/work/pki/config"
CLIENT_DIR="${OUT_DIR}/clients/${TARGET}"

case "${TARGET}" in
order-service)
  EXT_NAME="v3_client_order"
  ;;
inventory-service)
  EXT_NAME="v3_client_inventory"
  ;;
unauthorized-client)
  EXT_NAME="v3_client_unauthorized"
  ;;
*)
  echo "Unsupported rotation target: ${TARGET}" >&2
  exit 1
  ;;
esac

OLD_SERIAL=$(openssl x509 -in "${CLIENT_DIR}/current/${TARGET}.crt" -noout -serial | cut -d= -f2)
echo "Old ${TARGET} certificate serial: ${OLD_SERIAL}"

STAGING_DIR="${CLIENT_DIR}/staging"
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

openssl ecparam -name prime256v1 -genkey -noout -out "${STAGING_DIR}/${TARGET}.key"
openssl req -new -key "${STAGING_DIR}/${TARGET}.key" -sha256 \
  -subj "/C=PL/O=Internal Cloud Platform/CN=${TARGET}" \
  -out "${STAGING_DIR}/${TARGET}.csr"

openssl ca -batch -notext -config "${CFG_DIR}/intermediate-ca.cnf" \
  -extfile "${CFG_DIR}/extensions.cnf" -extensions "${EXT_NAME}" \
  -in "${STAGING_DIR}/${TARGET}.csr" \
  -out "${STAGING_DIR}/${TARGET}.crt" >/dev/null 2>&1

cat "${STAGING_DIR}/${TARGET}.crt" "${OUT_DIR}/intermediate/intermediate-ca.crt" \
  >"${STAGING_DIR}/fullchain.pem"
rm -f "${STAGING_DIR}/${TARGET}.csr"

NEW_SERIAL=$(openssl x509 -in "${STAGING_DIR}/${TARGET}.crt" -noout -serial | cut -d= -f2)
mv "${STAGING_DIR}" "${CLIENT_DIR}/releases/${NEW_SERIAL}"

ln -sfn "releases/${NEW_SERIAL}" "${CLIENT_DIR}/current"

echo "New ${TARGET} certificate serial: ${NEW_SERIAL} (atomic symlink updated)"
