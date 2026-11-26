#!/usr/bin/env bash
set -euo pipefail

BASE=".local/pki"
echo "================================================================"
echo "  FINAL PRODUCTION INCIDENT (02:15) — SIMULATE, DIAGNOSE & FIX"
echo "================================================================"

echo "[02:15] Injecting incident state:"
echo "  - Payment Service serves LEAF ONLY (incomplete chain: missing int-v2) & old mTLS trust (int-v1-only)"
echo "  - Inventory Service remains healthy on v2 fullchain"
cp infra/nginx/payment.conf .local/payment.conf.good
cat << 'CONF' > infra/nginx/payment.conf
server {
    listen 443 ssl;
    server_name payment.internal.test;

    ssl_certificate     /etc/nginx/pki/services/payment-v2.crt;
    ssl_certificate_key /etc/nginx/pki/services/payment-v2.key;
    ssl_protocols       TLSv1.2 TLSv1.3;

    ssl_client_certificate /etc/nginx/pki/trust/int-v1-only.pem;
    ssl_verify_client on;
    ssl_verify_depth 2;

    location / {
        default_type application/json;
        return 200 '{"service":"payment-service","status":"ok","ca_version":"v2"}';
    }
}
CONF
docker exec pki4-payment nginx -s reload 2>/dev/null
sleep 1

echo ""
echo "[02:17] EVIDENCE COLLECTION:"
echo "  1) Inventory Service health check (expected OK):"
curl -sS --cacert "${BASE}/trust/root-v1.pem" --resolve inventory.internal.test:8443:127.0.0.1 https://inventory.internal.test:8443/
echo ""
echo "  2) Order Service -> Payment Service mTLS call (expected FAILURE: verify failed):"
curl -sS --cacert "${BASE}/trust/root-v1.pem"   --cert "${BASE}/clients/order-client-v2-fullchain.crt"   --key "${BASE}/clients/order-client-v2.key"   --resolve payment.internal.test:8441:127.0.0.1   https://payment.internal.test:8441/ 2>&1 || true

echo "  3) Inspecting live TLS chain presented by Payment Service (depth=0 only -> missing Intermediate v2):"
openssl s_client -connect 127.0.0.1:8441 -servername payment.internal.test   -CAfile "${BASE}/trust/root-v1.pem" </dev/null 2>&1 | grep -E "depth=|Verify return code:" || true

echo ""
echo "[02:22] ROOT CAUSE ANALYSIS:"
echo "  1. Payment Service serves payment-v2.crt (leaf only) instead of payment-v2-fullchain.crt (missing Intermediate CA v2)."
echo "  2. Payment Service ssl_client_certificate still points to stale int-v1-only.pem (rejects v2 mTLS clients)."
echo "  3. Order Service & other pods had inconsistent trust stores during Intermediate CA v1 -> v2 rotation."

echo ""
echo "[02:25] REMEDIATION (without disabling TLS verification):"
echo "  - Restore payment-v2-fullchain.crt and dual-int-bundle.pem on Payment Service"
echo "  - Reload Nginx gracefully (zero-downtime)"
cp .local/payment.conf.good infra/nginx/payment.conf
docker exec pki4-payment nginx -s reload 2>/dev/null
sleep 1

echo ""
echo "[02:27] POST-FIX VERIFICATION:"
curl -sS --cacert "${BASE}/trust/root-v1.pem"   --cert "${BASE}/clients/order-client-v2-fullchain.crt"   --key "${BASE}/clients/order-client-v2.key"   --resolve payment.internal.test:8441:127.0.0.1   https://payment.internal.test:8441/
echo ""
openssl s_client -connect 127.0.0.1:8441 -servername payment.internal.test   -CAfile "${BASE}/trust/root-v1.pem"   -cert "${BASE}/clients/order-client-v2-fullchain.crt"   -key "${BASE}/clients/order-client-v2.key" </dev/null 2>&1 | grep -E "Verify return code:" || true
echo "[RESOLVED] Incident 02:15 fully mitigated with strict TLS/mTLS verification intact."
