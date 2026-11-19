#!/usr/bin/env bash
set -euo pipefail
umask 077

OUT_DIR="/work/pki/out"
CFG_DIR="/work/pki/config"

mkdir -p "${OUT_DIR}"
rm -rf "${OUT_DIR:?}"/*
mkdir -p "${OUT_DIR}"/{root/db/newcerts,rogue,intermediate/db/newcerts,servers,clients,trust,crl}
touch "${OUT_DIR}/root/db/index.txt" "${OUT_DIR}/intermediate/db/index.txt"
echo "1000" >"${OUT_DIR}/root/db/serial"
echo "1000" >"${OUT_DIR}/root/db/crlnumber"
echo "1000" >"${OUT_DIR}/intermediate/db/serial"
echo "1000" >"${OUT_DIR}/intermediate/db/crlnumber"

echo "[1/6] Generating Company Root CA (ECDSA P-384) & Rogue Root CA"
openssl ecparam -name secp384r1 -genkey -noout -out "${OUT_DIR}/root/root-ca.key"
openssl req -x509 -new -key "${OUT_DIR}/root/root-ca.key" -sha384 -days 3650 \
  -config "${CFG_DIR}/root-ca.cnf" -out "${OUT_DIR}/root/root-ca.crt"

openssl ecparam -name secp384r1 -genkey -noout -out "${OUT_DIR}/rogue/rogue-ca.key"
openssl req -x509 -new -key "${OUT_DIR}/rogue/rogue-ca.key" -sha384 -days 3650 \
  -config "${CFG_DIR}/rogue-ca.cnf" -out "${OUT_DIR}/rogue/rogue-ca.crt"

echo "[2/6] Generating Intermediate CA (ECDSA P-384, pathlen:0)"
openssl ecparam -name secp384r1 -genkey -noout -out "${OUT_DIR}/intermediate/intermediate-ca.key"
openssl req -new -key "${OUT_DIR}/intermediate/intermediate-ca.key" -sha384 \
  -subj "/C=PL/O=Internal Cloud Platform/OU=Platform Security/CN=Internal Services Intermediate CA" \
  -out "${OUT_DIR}/intermediate/intermediate-ca.csr"
openssl ca -batch -notext -config "${CFG_DIR}/root-ca-db.cnf" \
  -extfile "${CFG_DIR}/extensions.cnf" -extensions v3_intermediate \
  -in "${OUT_DIR}/intermediate/intermediate-ca.csr" \
  -out "${OUT_DIR}/intermediate/intermediate-ca.crt" >/dev/null 2>&1

echo "[3/6] Building Explicit Trust Stores (Company vs Rogue)"
cp "${OUT_DIR}/root/root-ca.crt" "${OUT_DIR}/trust/company-truststore.pem"
cp "${OUT_DIR}/rogue/rogue-ca.crt" "${OUT_DIR}/trust/rogue-truststore.pem"

issue_cert() {
  local kind="$1"
  local name="$2"
  local cn="$3"
  local ext="$4"
  shift 4
  local extra_args=("$@")

  local base_dir="${OUT_DIR}/${kind}/${name}"
  local staging_dir="${base_dir}/staging"
  mkdir -p "${staging_dir}" "${base_dir}/releases"

  openssl ecparam -name prime256v1 -genkey -noout -out "${staging_dir}/${name}.key"
  openssl req -new -key "${staging_dir}/${name}.key" -sha256 \
    -subj "/C=PL/O=Internal Cloud Platform/CN=${cn}" \
    -out "${staging_dir}/${name}.csr"

  openssl ca -batch -notext -config "${CFG_DIR}/intermediate-ca.cnf" \
    -extfile "${CFG_DIR}/extensions.cnf" -extensions "${ext}" \
    "${extra_args[@]}" \
    -in "${staging_dir}/${name}.csr" \
    -out "${staging_dir}/${name}.crt" >/dev/null 2>&1

  cat "${staging_dir}/${name}.crt" "${OUT_DIR}/intermediate/intermediate-ca.crt" \
    >"${staging_dir}/fullchain.pem"
  rm -f "${staging_dir}/${name}.csr"

  local serial
  serial=$(openssl x509 -in "${staging_dir}/${name}.crt" -noout -serial | cut -d= -f2)
  mv "${staging_dir}" "${base_dir}/releases/${serial}"
  ln -sfn "releases/${serial}" "${base_dir}/current"
}

echo "[4/6] Issuing Server Certificates (payments.internal.test + wrong-san)"
issue_cert "servers" "payments.internal.test" "payments.internal.test" "v3_server_payments"
issue_cert "servers" "wrong-san" "wrong-payments.internal.test" "v3_server_wrong_san"

echo "[5/6] Issuing Client Certificates (valid, expired, wrong-eku, rogue)"
NOW_EPOCH=$(date -u +%s)
EXP_START=$(date -u -d "@$((NOW_EPOCH - 172800))" +%Y%m%d%H%M%SZ)
EXP_END=$(date -u -d "@$((NOW_EPOCH - 86400))" +%Y%m%d%H%M%SZ)

issue_cert "clients" "order-service" "order-service" "v3_client_order"
issue_cert "clients" "inventory-service" "inventory-service" "v3_client_inventory"
issue_cert "clients" "unauthorized-client" "unauthorized-client" "v3_client_unauthorized"
issue_cert "clients" "expired-client" "expired-client" "v3_client_expired" -startdate "${EXP_START}" -enddate "${EXP_END}"
issue_cert "clients" "wrong-eku-client" "wrong-eku-client" "v3_client_wrong_eku"

ROGUE_BASE="${OUT_DIR}/clients/rogue-client"
mkdir -p "${ROGUE_BASE}/staging" "${ROGUE_BASE}/releases"
openssl ecparam -name prime256v1 -genkey -noout -out "${ROGUE_BASE}/staging/rogue-client.key"
openssl req -new -key "${ROGUE_BASE}/staging/rogue-client.key" -sha256 \
  -subj "/C=US/O=External Rogue Corp/CN=order-service" \
  -out "${ROGUE_BASE}/staging/rogue-client.csr"
openssl x509 -req -in "${ROGUE_BASE}/staging/rogue-client.csr" \
  -CA "${OUT_DIR}/rogue/rogue-ca.crt" -CAkey "${OUT_DIR}/rogue/rogue-ca.key" -CAcreateserial \
  -sha256 -days 90 -extfile "${CFG_DIR}/extensions.cnf" -extensions v3_client_order \
  -out "${ROGUE_BASE}/staging/rogue-client.crt" >/dev/null 2>&1
cp "${ROGUE_BASE}/staging/rogue-client.crt" "${ROGUE_BASE}/staging/fullchain.pem"
rm -f "${ROGUE_BASE}/staging/rogue-client.csr"
ROGUE_SERIAL=$(openssl x509 -in "${ROGUE_BASE}/staging/rogue-client.crt" -noout -serial | cut -d= -f2)
mv "${ROGUE_BASE}/staging" "${ROGUE_BASE}/releases/${ROGUE_SERIAL}"
ln -sfn "releases/${ROGUE_SERIAL}" "${ROGUE_BASE}/current"

echo "[6/6] Generating Initial CRL Bundle & Verifying Valid Chains"
openssl ca -batch -config "${CFG_DIR}/root-ca-db.cnf" -gencrl \
  -crlexts crl_ext -out "${OUT_DIR}/crl/root.crl.pem" >/dev/null 2>&1
openssl ca -batch -config "${CFG_DIR}/intermediate-ca.cnf" -gencrl \
  -crlexts crl_ext -out "${OUT_DIR}/crl/intermediate.crl.pem" >/dev/null 2>&1
cat "${OUT_DIR}/crl/intermediate.crl.pem" "${OUT_DIR}/crl/root.crl.pem" >"${OUT_DIR}/crl/crl-bundle.pem"

openssl verify -CAfile "${OUT_DIR}/trust/company-truststore.pem" \
  -untrusted "${OUT_DIR}/intermediate/intermediate-ca.crt" \
  "${OUT_DIR}/servers/payments.internal.test/current/payments.internal.test.crt" \
  "${OUT_DIR}/clients/order-service/current/order-service.crt" \
  "${OUT_DIR}/clients/inventory-service/current/inventory-service.crt" \
  "${OUT_DIR}/clients/unauthorized-client/current/unauthorized-client.crt"

echo "PKI, Trust Stores, Client Certificates, and CRL bundle generated successfully."
