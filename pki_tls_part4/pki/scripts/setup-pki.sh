#!/usr/bin/env bash
set -euo pipefail
umask 077

BASE=".local/pki"
rm -rf "${BASE}"
mkdir -p "${BASE}"/{root-v1,root-v2,int-v1,int-v2,services,clients,trust,troubleshoot}

init_ca_db() {
  local dir="$1"
  mkdir -p "${dir}/newcerts"
  touch "${dir}/index.txt"
  echo "1000" > "${dir}/serial"
  echo "1000" > "${dir}/crlnumber"
}

init_ca_db "${BASE}/root-v1"
init_ca_db "${BASE}/root-v2"
init_ca_db "${BASE}/int-v1"
init_ca_db "${BASE}/int-v2"

cat << 'CFG' > "${BASE}/openssl-ca.cnf"
[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = .
certs             = $dir
new_certs_dir     = $dir/newcerts
database          = $dir/index.txt
serial            = $dir/serial
crlnumber         = $dir/crlnumber
default_md        = sha256
preserve          = no
policy            = policy_loose
default_crl_days  = 7

[ policy_loose ]
countryName             = optional
organizationName        = optional
commonName              = supplied

[ v3_root_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ v3_intermediate_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ v3_server ]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer

[ v3_client ]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature
extendedKeyUsage = clientAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
CFG

echo "[1/5] Generating Root CA v1 & Root CA v2"
openssl genrsa -out "${BASE}/root-v1/ca.key" 4096 2>/dev/null
openssl req -x509 -new -nodes -key "${BASE}/root-v1/ca.key" -sha256 -days 3650   -subj "/C=PL/O=CloudAcademy/CN=CloudAcademy Root CA v1"   -config "${BASE}/openssl-ca.cnf" -extensions v3_root_ca   -out "${BASE}/root-v1/ca.crt"

openssl genrsa -out "${BASE}/root-v2/ca.key" 4096 2>/dev/null
openssl req -x509 -new -nodes -key "${BASE}/root-v2/ca.key" -sha256 -days 3650   -subj "/C=PL/O=CloudAcademy/CN=CloudAcademy Root CA v2"   -config "${BASE}/openssl-ca.cnf" -extensions v3_root_ca   -out "${BASE}/root-v2/ca.crt"

echo "[2/5] Generating Intermediate CA v1 & Intermediate CA v2"
for ver in v1 v2; do
  openssl genrsa -out "${BASE}/int-${ver}/ca.key" 2048 2>/dev/null
  openssl req -new -key "${BASE}/int-${ver}/ca.key"     -subj "/C=PL/O=CloudAcademy/CN=CloudAcademy Intermediate CA ${ver}"     -out "${BASE}/int-${ver}/ca.csr"
  openssl ca -batch -config "${BASE}/openssl-ca.cnf"     -cert "${BASE}/root-v1/ca.crt" -keyfile "${BASE}/root-v1/ca.key"     -outdir "${BASE}/root-v1/newcerts" -extensions v3_intermediate_ca     -days 1825 -notext -md sha256     -in "${BASE}/int-${ver}/ca.csr" -out "${BASE}/int-${ver}/ca.crt"     -updatedb 2>/dev/null ||   openssl x509 -req -in "${BASE}/int-${ver}/ca.csr"     -CA "${BASE}/root-v1/ca.crt" -CAkey "${BASE}/root-v1/ca.key" -CAcreateserial     -out "${BASE}/int-${ver}/ca.crt" -days 1825 -sha256     -extfile "${BASE}/openssl-ca.cnf" -extensions v3_intermediate_ca 2>/dev/null
done

echo "[3/5] Issuing initial v1 certificates for payment, order, inventory & mTLS client"
issue_leaf() {
  local ca_ver="$1" name="$2" dns="$3" type="$4" days="${5:-30}"
  local out="${BASE}/services/${name}-${ca_ver}"
  [[ "${type}" == "client" ]] && out="${BASE}/clients/${name}-${ca_ver}"
  openssl genrsa -out "${out}.key" 2048 2>/dev/null
  openssl req -new -key "${out}.key" -subj "/C=PL/O=CloudAcademy/CN=${dns}" -out "${out}.csr"
  cat << EXT > "${out}.ext"
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = $( [[ "${type}" == "client" ]] && echo "clientAuth" || echo "serverAuth" )
subjectAltName = DNS:${dns},DNS:localhost,IP:127.0.0.1
EXT
  openssl x509 -req -in "${out}.csr"     -CA "${BASE}/int-${ca_ver}/ca.crt" -CAkey "${BASE}/int-${ca_ver}/ca.key" -CAcreateserial     -out "${out}.crt" -days "${days}" -sha256 -extfile "${out}.ext" 2>/dev/null
  cat "${out}.crt" "${BASE}/int-${ca_ver}/ca.crt" > "${out}-fullchain.crt"
}

for svc in payment order inventory; do
  issue_leaf "v1" "${svc}" "${svc}.internal.test" "server" 30
  issue_leaf "v2" "${svc}" "${svc}.internal.test" "server" 30
done
issue_leaf "v1" "order-client" "order-client.internal.test" "client" 30
issue_leaf "v2" "order-client" "order-client.internal.test" "client" 30

echo "[4/5] Building Trust Bundles (root-v1, int-v1-only, int-v2-only, dual-int, dual-root)"
cp "${BASE}/root-v1/ca.crt" "${BASE}/trust/root-v1.pem"
cp "${BASE}/int-v1/ca.crt" "${BASE}/trust/int-v1-only.pem"
cp "${BASE}/int-v2/ca.crt" "${BASE}/trust/int-v2-only.pem"
cat "${BASE}/root-v1/ca.crt" "${BASE}/int-v1/ca.crt" "${BASE}/int-v2/ca.crt" > "${BASE}/trust/dual-int-bundle.pem"
cat "${BASE}/root-v1/ca.crt" "${BASE}/root-v2/ca.crt" > "${BASE}/trust/dual-root-bundle.pem"

echo "[5/5] PKI v1 & v2 bootstrap complete."
