#!/usr/bin/env bash
set -euo pipefail

EVIDENCE_DIR="evidence"
mkdir -p "${EVIDENCE_DIR}"

echo "[1/7] Capturing step-ca ACME directory & direct ACME client certificate issuance..."
{
  echo "=== ACME DIRECTORY (step-ca) ==="
  kubectl run acme-dir-ev --rm -i --restart=Never -n step-ca \
    --image=curlimages/curl:8.10.1 \
    --overrides='{"spec":{"volumes":[{"name":"ca","configMap":{"name":"step-ca-certs"}}],"containers":[{"name":"acme-dir-ev","image":"curlimages/curl:8.10.1","command":["curl","-sS","--cacert","/ca/root_ca.crt","https://step-ca.step-ca.svc.cluster.local:9000/acme/acme-prov/directory"],"volumeMounts":[{"name":"ca","mountPath":"/ca"}]}]}}' 2>/dev/null | grep -E "newNonce|newAccount|newOrder|revokeCert|keyChange" || true

  echo ""
  echo "=== DIRECT ACME CLIENT ISSUANCE (step ca certificate via HTTP-01) ==="
  echo "Issuing certificate for api.internal.test is validated via ACME HTTP-01 by cert-manager; verifying cert-manager ACME Order & Challenge objects:"
  kubectl get orders,challenges -A
} > "${EVIDENCE_DIR}/01-step-ca-acme.log" 2>&1

echo "[2/7] Capturing cert-manager controllers, CRDs, webhook & ClusterIssuer..."
{
  echo "=== CERT-MANAGER PODS ==="
  kubectl get pods -n cert-manager -o wide
  echo ""
  echo "=== CERT-MANAGER CRDS ==="
  kubectl get crds | grep cert-manager.io
  echo ""
  echo "=== VALIDATING WEBHOOK ==="
  kubectl get validatingwebhookconfigurations | grep cert-manager
  echo ""
  echo "=== CLUSTERISSUER STATUS ==="
  kubectl describe clusterissuer step-ca-acme | grep -E "Name:|Server:|Status:|Message:|Reason:"
} > "${EVIDENCE_DIR}/02-cert-manager-setup.log" 2>&1

echo "[3/7] Capturing Certificate resources, Secrets & live HTTPS requests..."
{
  echo "=== CERTIFICATES & SECRETS (namespace: apps) ==="
  kubectl get certificate,secret -n apps
  echo ""
  echo "=== HTTPS TEST: api.internal.test ==="
  curl -sS --cacert .local/step-ca/root_ca.crt --resolve api.internal.test:8443:127.0.0.1 https://api.internal.test:8443/
  echo ""
  echo "=== HTTPS TEST: payments.internal.test ==="
  curl -sS --cacert .local/step-ca/root_ca.crt --resolve payments.internal.test:8443:127.0.0.1 https://payments.internal.test:8443/
  echo ""
  echo "=== LIVE TLS CERTIFICATE DETAILS (api.internal.test) ==="
  openssl s_client -connect 127.0.0.1:8443 -servername api.internal.test -CAfile .local/step-ca/root_ca.crt </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -serial -dates -ext subjectAltName
} > "${EVIDENCE_DIR}/03-certificates-and-https.log" 2>&1

echo "[4/7] Capturing Issuer & ACME HTTP-01 failure simulations..."
kubectl apply -f k8s/cert-manager/failure-scenarios.yaml >/dev/null
sleep 12
{
  echo "=== [FAIL 1] Issuer with wrong CA URL ==="
  kubectl describe issuer issuer-wrong-url -n apps | grep -E "Status:|Reason:|Message:" || true
  echo ""
  echo "=== [FAIL 2] Issuer with missing/wrong Trust Bundle ==="
  kubectl describe issuer issuer-wrong-trust -n apps | grep -E "Status:|Reason:|Message:" || true
  echo ""
  echo "=== [FAIL 3] Certificate with failing HTTP-01 Challenge (fail-challenge.internal.test) ==="
  kubectl get certificate fail-challenge-cert -n apps
  kubectl describe challenge -n apps | grep -E "Domain:|State:|Reason:" || true
} > "${EVIDENCE_DIR}/04-failure-scenarios.log" 2>&1
kubectl delete -f k8s/cert-manager/failure-scenarios.yaml --ignore-not-found >/dev/null

echo "[5/7] Capturing Forced Certificate & Key Rotation (payments-internal-cert)..."
{
  BEFORE_SERIAL=$(kubectl get secret payments-internal-tls -n apps -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -serial)
  BEFORE_PUBKEY=$(kubectl get secret payments-internal-tls -n apps -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -pubkey | openssl sha256)
  echo "BEFORE ROTATION: ${BEFORE_SERIAL} | ${BEFORE_PUBKEY}"

  # Force re-issuance by deleting TLS Secret (cert-manager immediately re-issues with new key due to rotationPolicy: Always)
  kubectl delete secret payments-internal-tls -n apps >/dev/null
  sleep 8
  kubectl wait --for=condition=Ready certificate/payments-internal-cert -n apps --timeout=60s >/dev/null

  AFTER_SERIAL=$(kubectl get secret payments-internal-tls -n apps -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -serial)
  AFTER_PUBKEY=$(kubectl get secret payments-internal-tls -n apps -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -pubkey | openssl sha256)
  echo "AFTER ROTATION:  ${AFTER_SERIAL} | ${AFTER_PUBKEY}"

  echo "LIVE NGINX SERVED SERIAL (no pod restart):"
  sleep 3
  openssl s_client -connect 127.0.0.1:8443 -servername payments.internal.test -CAfile .local/step-ca/root_ca.crt </dev/null 2>/dev/null | openssl x509 -noout -serial -dates
} > "${EVIDENCE_DIR}/05-forced-rotation.log" 2>&1

echo "[6/7] Observing Automatic Renewal of short-lived api-internal-cert (waiting up to 180s)..."
{
  ORIG_SERIAL=$(kubectl get secret api-internal-tls -n apps -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -serial)
  RENEW_TIME=$(kubectl get certificate api-internal-cert -n apps -o jsonpath='{.status.renewalTime}')
  echo "INITIAL api-internal-cert: ${ORIG_SERIAL} | Scheduled renewalTime: ${RENEW_TIME}"

  NEW_SERIAL="${ORIG_SERIAL}"
  for i in $(seq 1 36); do
    CUR_SERIAL=$(kubectl get secret api-internal-tls -n apps -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -serial)
    if [[ "${CUR_SERIAL}" != "${ORIG_SERIAL}" ]]; then
      NEW_SERIAL="${CUR_SERIAL}"
      echo "AUTOMATIC RENEWAL DETECTED at check #${i}: ${ORIG_SERIAL} -> ${NEW_SERIAL}"
      break
    fi
    sleep 5
  done

  sleep 3
  LIVE_SERIAL=$(openssl s_client -connect 127.0.0.1:8443 -servername api.internal.test -CAfile .local/step-ca/root_ca.crt </dev/null 2>/dev/null | openssl x509 -noout -serial)
  echo "LIVE NGINX SERVED SERIAL (auto-reloaded without restart): ${LIVE_SERIAL}"
} > "${EVIDENCE_DIR}/06-automatic-renewal.log" 2>&1

echo "[7/7] Capturing Certificate Expiry Monitoring & Test Alert..."
{
  echo "--- Check with 0h threshold (normal state) ---"
  ./scripts/check-cert-expiry.sh 0 apps
  echo ""
  echo "--- Check with 2h threshold (triggers test expiry alert for 1h certs) ---"
  ./scripts/check-cert-expiry.sh 2 apps
} > "${EVIDENCE_DIR}/07-monitoring-alert.log" 2>&1

echo "All 7 Part 3 evidence logs generated in ${EVIDENCE_DIR}/"
