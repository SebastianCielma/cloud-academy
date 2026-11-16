SHELL := /usr/bin/env bash -o pipefail
OPENSSL_IMAGE := alpine:3.20
COMPOSE_FILE := infra/docker-compose.yml
EDGE_NETWORK := infra_edge_net
EVIDENCE_DIR := evidence

DOCKER_RUN := docker run --rm -v "$(CURDIR):/work" -w /work $(OPENSSL_IMAGE)
NET_CLIENT := docker run --rm --network $(EDGE_NETWORK) -v "$(CURDIR):/work" -w /work $(OPENSSL_IMAGE)

.PHONY: pki inspect up down test-tls test-errors evidence clean

pki:
	chmod +x pki/scripts/generate-pki.sh
	$(DOCKER_RUN) sh -c "apk add --no-cache openssl bash >/dev/null && ./pki/scripts/generate-pki.sh"

inspect:
	$(DOCKER_RUN) sh -c "apk add --no-cache openssl >/dev/null && \
		echo '=== ROOT CA ===' && \
		openssl x509 -in pki/out/root/root-ca.crt -noout -subject -issuer -ext basicConstraints,keyUsage && \
		echo '=== INTERMEDIATE CA ===' && \
		openssl x509 -in pki/out/intermediate/intermediate-ca.crt -noout -subject -issuer -ext basicConstraints,keyUsage && \
		echo '=== SERVER LEAF (api.internal.test) ===' && \
		openssl x509 -in pki/out/servers/api.internal.test/server.crt -noout -subject -issuer -ext basicConstraints,keyUsage,extendedKeyUsage,subjectAltName"

up:
	docker compose -f $(COMPOSE_FILE) up -d

down:
	docker compose -f $(COMPOSE_FILE) down

test-tls:
	$(NET_CLIENT) sh -c "apk add --no-cache curl openssl >/dev/null && \
		echo '--- [1] Valid HTTPS Request via SNI (api & payments) ---' && \
		curl -sS --cacert pki/out/root/root-ca.crt https://api.internal.test/api && echo '' && \
		curl -sS --cacert pki/out/root/root-ca.crt https://payments.internal.test/payments && echo '' && \
		echo '--- [2] TLS 1.3 Handshake & Cipher ---' && \
		openssl s_client -connect api.internal.test:443 -servername api.internal.test -CAfile pki/out/root/root-ca.crt -tls1_3 </dev/null 2>/dev/null | grep -E 'Protocol|Cipher|Verify return code' && \
		echo '--- [3] TLS 1.2 Handshake & Cipher ---' && \
		openssl s_client -connect api.internal.test:443 -servername api.internal.test -CAfile pki/out/root/root-ca.crt -tls1_2 </dev/null 2>/dev/null | grep -E 'Protocol|Cipher|Verify return code'"

test-errors:
	$(NET_CLIENT) sh -c "apk add --no-cache curl openssl >/dev/null; \
		echo '=== [ERR 1] Unknown CA (no --cacert provided) ==='; \
		curl -sS https://api.internal.test/api || true; \
		echo ''; \
		echo '=== [ERR 2] Incomplete Chain (missing Intermediate on port 8443) ==='; \
		curl -sS --cacert pki/out/root/root-ca.crt https://api.internal.test:8443/api || true; \
		echo ''; \
		echo '=== [ERR 3] SAN / Hostname Mismatch (inventory.internal.test hits default api cert) ==='; \
		curl -sS --cacert pki/out/root/root-ca.crt https://inventory.internal.test/api || true; \
		echo ''; \
		echo '=== [ERR 4] Legacy TLS 1.1 Rejected by Server (@SECLEVEL=0 forces ClientHello) ==='; \
		openssl s_client -connect api.internal.test:443 -servername api.internal.test -tls1_1 -cipher 'DEFAULT@SECLEVEL=0' </dev/null 2>&1 | grep -E 'error|alert|Protocol' || true; \
		echo ''; \
		echo '=== [ERR 5] Wrong Chain Order (Intermediate before Leaf in TLS server) ==='; \
		cat pki/out/intermediate/intermediate-ca.crt pki/out/servers/api.internal.test/server.crt > /tmp/bad-order.pem; \
		openssl s_server -accept 9443 -cert /tmp/bad-order.pem -key pki/out/servers/api.internal.test/server.key 2>&1 || true"

evidence: up
	mkdir -p $(EVIDENCE_DIR)
	@echo "[1/4] Capturing PKI generation & chain verification log..."
	$(MAKE) pki | tee $(EVIDENCE_DIR)/01-pki-generation.log
	@echo "[1.5/4] Validating Nginx syntax and reloading rotated certificates..."
	docker exec pki-nginx-edge nginx -t && docker exec pki-nginx-edge nginx -s reload
	@echo "[2/4] Capturing full X.509 certificate structure analysis..."
	$(DOCKER_RUN) sh -c "apk add --no-cache openssl >/dev/null && \
		echo '=== ROOT CA X.509 STRUCTURE ===' && \
		openssl x509 -in pki/out/root/root-ca.crt -noout -text && \
		echo '=== INTERMEDIATE CA X.509 STRUCTURE ===' && \
		openssl x509 -in pki/out/intermediate/intermediate-ca.crt -noout -text && \
		echo '=== LEAF CERTIFICATE (api.internal.test) X.509 STRUCTURE ===' && \
		openssl x509 -in pki/out/servers/api.internal.test/server.crt -noout -text" \
		> $(EVIDENCE_DIR)/02-x509-inspection.log
	@echo "[3/4] Capturing valid TLS 1.2 / TLS 1.3 handshakes & curl -v..."
	$(NET_CLIENT) sh -c "apk add --no-cache curl openssl >/dev/null && \
		echo '=== CURL VERBOSE (VALID ROOT CA - api.internal.test) ===' && \
		curl -v --cacert pki/out/root/root-ca.crt https://api.internal.test/api 2>&1 && \
		echo '=== CURL VERBOSE (SNI ROUTED - payments.internal.test) ===' && \
		curl -v --cacert pki/out/root/root-ca.crt https://payments.internal.test/payments 2>&1 && \
		echo '=== OPENSSL S_CLIENT TLS 1.3 ===' && \
		openssl s_client -connect api.internal.test:443 -servername api.internal.test -CAfile pki/out/root/root-ca.crt -tls1_3 </dev/null 2>&1 && \
		echo '=== OPENSSL S_CLIENT TLS 1.2 ===' && \
		openssl s_client -connect api.internal.test:443 -servername api.internal.test -CAfile pki/out/root/root-ca.crt -tls1_2 </dev/null 2>&1" \
		> $(EVIDENCE_DIR)/03-tls-valid-handshake.log
	@echo "[4/4] Capturing TLS failure simulations..."
	$(MAKE) test-errors > $(EVIDENCE_DIR)/04-tls-failure-modes.log 2>&1
	@echo "All audit logs saved to $(EVIDENCE_DIR)/"

clean:
	docker compose -f $(COMPOSE_FILE) down -v 2>/dev/null || true
	rm -rf pki/out $(EVIDENCE_DIR)
