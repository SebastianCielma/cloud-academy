SHELL := /usr/bin/env bash -o pipefail
OPENSSL_IMAGE := alpine:3.20
COMPOSE_FILE := infra/docker-compose.yml
COMPOSE_PROJECT_NAME ?= pki_tls_part2
EDGE_NETWORK := $(COMPOSE_PROJECT_NAME)_edge_net
EVIDENCE_DIR := evidence

DOCKER_RUN := docker run --rm -v "$(CURDIR):/work" -w /work $(OPENSSL_IMAGE)
NET_CLIENT := docker run --rm --network $(EDGE_NETWORK) -v "$(CURDIR):/work" -w /work $(OPENSSL_IMAGE)

.PHONY: pki up down evidence verify clean

pki:
	chmod +x pki/scripts/*.sh
	$(DOCKER_RUN) sh -c "apk add --no-cache openssl bash >/dev/null && ./pki/scripts/generate-pki.sh"

up:
	docker compose -p $(COMPOSE_PROJECT_NAME) -f $(COMPOSE_FILE) up -d --force-recreate
	@echo "Waiting for Nginx edge and order-service readiness..."
	@docker exec mtls-nginx-edge nginx -t >/dev/null
	@docker exec mtls-order-service sh -c "until command -v curl >/dev/null 2>&1; do sleep 0.5; done"

down:
	docker compose -p $(COMPOSE_PROJECT_NAME) -f $(COMPOSE_FILE) down

evidence: pki up
	docker exec mtls-nginx-edge nginx -s reload
	mkdir -p $(EVIDENCE_DIR)

	@echo "[1/6] Capturing PKI, EKU comparison (serverAuth vs clientAuth), and Trust Stores"
	$(DOCKER_RUN) sh -c "apk add --no-cache openssl >/dev/null && \
		echo '=== PEM HEADER CHECK (-notext) ===' && \
		head -n 1 pki/out/clients/order-service/current/order-service.crt && \
		echo '=== SERVER EKU (payments.internal.test) ===' && \
		openssl x509 -in pki/out/servers/payments.internal.test/current/payments.internal.test.crt -noout -subject -issuer -ext extendedKeyUsage,subjectAltName && \
		echo '=== CLIENT EKU (order-service) ===' && \
		openssl x509 -in pki/out/clients/order-service/current/order-service.crt -noout -subject -issuer -ext extendedKeyUsage,subjectAltName && \
		echo '=== CLIENT EKU (inventory-service) ===' && \
		openssl x509 -in pki/out/clients/inventory-service/current/inventory-service.crt -noout -subject -issuer -ext extendedKeyUsage,subjectAltName && \
		echo '=== CLIENT EKU (unauthorized-client) ===' && \
		openssl x509 -in pki/out/clients/unauthorized-client/current/unauthorized-client.crt -noout -subject -issuer -ext extendedKeyUsage,subjectAltName && \
		echo '=== TRUST STORES ===' && \
		openssl x509 -in pki/out/trust/company-truststore.pem -noout -subject -fingerprint && \
		openssl x509 -in pki/out/trust/rogue-truststore.pem -noout -subject -fingerprint" \
		> $(EVIDENCE_DIR)/01-pki-and-eku.log

	@echo "[2/6] Capturing Mutual TLS Handshake & Identity-Based Authorization (AuthN vs AuthZ)"
	{ \
		echo "=== [1] Order Service -> /payments/status (AuthN=OK, AuthZ=200) ==="; \
		docker exec mtls-order-service curl -i -sS \
			--cacert /certs/trust/company-truststore.pem \
			--cert /certs/client/current/fullchain.pem \
			--key /certs/client/current/order-service.key \
			https://payments.internal.test/payments/status; \
		echo ""; \
		echo "=== [2] Order Service -> /payments/charge (AuthN=OK, AuthZ=200 ALLOWED) ==="; \
		docker exec mtls-order-service curl -i -sS -X POST \
			--cacert /certs/trust/company-truststore.pem \
			--cert /certs/client/current/fullchain.pem \
			--key /certs/client/current/order-service.key \
			https://payments.internal.test/payments/charge; \
		echo ""; \
		$(NET_CLIENT) sh -c "apk add --no-cache curl >/dev/null && \
			echo '=== [3] Inventory Service -> /payments/status (AuthN=OK, AuthZ=200) ===' && \
			curl -i -sS --cacert pki/out/trust/company-truststore.pem \
				--cert pki/out/clients/inventory-service/current/fullchain.pem \
				--key pki/out/clients/inventory-service/current/inventory-service.key \
				https://payments.internal.test/payments/status && echo '' && \
			echo '=== [4] Inventory Service -> /payments/charge (AuthN=OK, AuthZ=403 FORBIDDEN) ===' && \
			curl -i -sS -X POST --cacert pki/out/trust/company-truststore.pem \
				--cert pki/out/clients/inventory-service/current/fullchain.pem \
				--key pki/out/clients/inventory-service/current/inventory-service.key \
				https://payments.internal.test/payments/charge && echo '' && \
			echo '=== [5] Unauthorized Client -> /payments/charge (AuthN=OK, AuthZ=403 FORBIDDEN) ===' && \
			curl -i -sS -X POST --cacert pki/out/trust/company-truststore.pem \
				--cert pki/out/clients/unauthorized-client/current/fullchain.pem \
				--key pki/out/clients/unauthorized-client/current/unauthorized-client.key \
				https://payments.internal.test/payments/charge"; \
	} > $(EVIDENCE_DIR)/02-mtls-authn-vs-authz.log 2>&1

	@echo "[3/6] Capturing Trust Store Isolation Tests (Company CA vs Rogue CA)"
	$(NET_CLIENT) sh -c "apk add --no-cache curl >/dev/null; \
		echo '=== [TRUST 1] Valid client cert, but client uses rogue-truststore.pem (Server CA untrusted) ==='; \
		curl -sS --cacert pki/out/trust/rogue-truststore.pem \
			--cert pki/out/clients/order-service/current/fullchain.pem \
			--key pki/out/clients/order-service/current/order-service.key \
			https://payments.internal.test/payments/status || true; \
		echo ''; \
		echo '=== [TRUST 2] Client trusts company CA, but presents rogue-client cert (CN=order-service signed by Rogue CA) ==='; \
		curl -i -sS --cacert pki/out/trust/company-truststore.pem \
			--cert pki/out/clients/rogue-client/current/fullchain.pem \
			--key pki/out/clients/rogue-client/current/rogue-client.key \
			https://payments.internal.test/payments/status || true" \
		> $(EVIDENCE_DIR)/03-trust-stores.log 2>&1

	@echo "[4/6] Capturing Broken Certificate Scenarios"
	$(NET_CLIENT) sh -c "apk add --no-cache curl >/dev/null; \
		echo '=== [ERR 1] Missing Client Certificate ==='; \
		curl -i -sS --cacert pki/out/trust/company-truststore.pem \
			https://payments.internal.test/payments/status || true; \
		echo ''; \
		echo '=== [ERR 2] Expired Client Certificate (expired-client) ==='; \
		curl -i -sS --cacert pki/out/trust/company-truststore.pem \
			--cert pki/out/clients/expired-client/current/fullchain.pem \
			--key pki/out/clients/expired-client/current/expired-client.key \
			https://payments.internal.test/payments/status || true; \
		echo ''; \
		echo '=== [ERR 3] Wrong EKU (serverAuth used as client cert) ==='; \
		curl -i -sS --cacert pki/out/trust/company-truststore.pem \
			--cert pki/out/clients/wrong-eku-client/current/fullchain.pem \
			--key pki/out/clients/wrong-eku-client/current/wrong-eku-client.key \
			https://payments.internal.test/payments/status || true; \
		echo ''; \
		echo '=== [ERR 4] Missing Intermediate CA (client sends leaf cert only) ==='; \
		curl -i -sS --cacert pki/out/trust/company-truststore.pem \
			--cert pki/out/clients/order-service/current/order-service.crt \
			--key pki/out/clients/order-service/current/order-service.key \
			https://payments.internal.test/payments/status || true; \
		echo ''; \
		echo '=== [ERR 5] Missing Intermediate CA on Server (port 8443) ==='; \
		curl -sS --cacert pki/out/trust/company-truststore.pem \
			--cert pki/out/clients/order-service/current/fullchain.pem \
			--key pki/out/clients/order-service/current/order-service.key \
			https://payments.internal.test:8443/payments/status || true; \
		echo ''; \
		echo '=== [ERR 6] Wrong Server SAN (port 8444 -> wrong-payments.internal.test) ==='; \
		curl -sS --cacert pki/out/trust/company-truststore.pem \
			--cert pki/out/clients/order-service/current/fullchain.pem \
			--key pki/out/clients/order-service/current/order-service.key \
			https://payments.internal.test:8444/payments/status || true; \
		echo ''; \
		echo '=== [ERR 7] Certificate / Private Key Mismatch ==='; \
		curl -sS --cacert pki/out/trust/company-truststore.pem \
			--cert pki/out/clients/order-service/current/fullchain.pem \
			--key pki/out/clients/inventory-service/current/inventory-service.key \
			https://payments.internal.test/payments/status || true" \
		> $(EVIDENCE_DIR)/04-broken-certificates.log 2>&1

	@echo "[5/6] Capturing Certificate Revocation (CRL Enforced vs Ignored)"
	{ \
		echo "=== [CRL 1] Revoking inventory-service certificate ==="; \
		$(DOCKER_RUN) sh -c "apk add --no-cache openssl bash >/dev/null && ./pki/scripts/revoke-cert.sh inventory-service"; \
		docker exec mtls-nginx-edge nginx -s reload; \
		echo ""; \
		echo "=== [CRL 2] Server WITH ssl_crl enabled (port 443 -> REJECTED) ==="; \
		$(NET_CLIENT) sh -c "apk add --no-cache curl >/dev/null && \
			curl -i -sS --cacert pki/out/trust/company-truststore.pem \
				--cert pki/out/clients/inventory-service/current/fullchain.pem \
				--key pki/out/clients/inventory-service/current/inventory-service.key \
				https://payments.internal.test/payments/status || true"; \
		echo ""; \
		echo "=== [CRL 3] Server WITHOUT ssl_crl (port 8445 -> STILL ACCEPTED!) ==="; \
		$(NET_CLIENT) sh -c "apk add --no-cache curl >/dev/null && \
			curl -i -sS --cacert pki/out/trust/company-truststore.pem \
				--cert pki/out/clients/inventory-service/current/fullchain.pem \
				--key pki/out/clients/inventory-service/current/inventory-service.key \
				https://payments.internal.test:8445/payments/status || true"; \
		echo ""; \
		echo "=== [CRL 4] Client fetches CRL via HTTP CDP & compares -crl_check vs no check ==="; \
		$(NET_CLIENT) sh -c "apk add --no-cache curl openssl >/dev/null && \
			curl -sS http://payments.internal.test/crl/intermediate.crl.pem -o /tmp/fetched.crl.pem && \
			echo '--- Client WITHOUT CRL check ---' && \
			openssl verify -CAfile pki/out/trust/company-truststore.pem -untrusted pki/out/intermediate/intermediate-ca.crt pki/out/clients/inventory-service/current/inventory-service.crt && \
			echo '--- Client WITH CRL check ---' && \
			openssl verify -crl_check -CAfile pki/out/trust/company-truststore.pem -untrusted pki/out/intermediate/intermediate-ca.crt -CRLfile /tmp/fetched.crl.pem pki/out/clients/inventory-service/current/inventory-service.crt || true"; \
	} > $(EVIDENCE_DIR)/05-crl-revocation.log 2>&1

	@echo "[6/6] Capturing Zero-Downtime Client Certificate Rotation & Post-Grace Revocation"
	{ \
		OLD_SERIAL=$$(openssl x509 -in pki/out/clients/order-service/current/order-service.crt -noout -serial | cut -d= -f2); \
		echo "=== [ROTATE 1] Before rotation: order-service serial $${OLD_SERIAL} in live mTLS request ==="; \
		docker exec mtls-order-service curl -i -sS \
			--cacert /certs/trust/company-truststore.pem \
			--cert /certs/client/current/fullchain.pem \
			--key /certs/client/current/order-service.key \
			https://payments.internal.test/payments/status | grep -E "HTTP/|X-Client-Cert-Serial|service"; \
		echo ""; \
		echo "=== [ROTATE 2] Rotating order-service atomically via symlink current -> releases/<new> ==="; \
		$(DOCKER_RUN) sh -c "apk add --no-cache openssl bash >/dev/null && ./pki/scripts/rotate-client-cert.sh order-service"; \
		echo ""; \
		echo "=== [ROTATE 3] During grace period: order-service immediately uses new serial (no restart) ==="; \
		docker exec mtls-order-service curl -i -sS \
			--cacert /certs/trust/company-truststore.pem \
			--cert /certs/client/current/fullchain.pem \
			--key /certs/client/current/order-service.key \
			https://payments.internal.test/payments/status | grep -E "HTTP/|X-Client-Cert-Serial|service"; \
		echo ""; \
		echo "=== [ROTATE 4] Grace period ended: revoking old serial $${OLD_SERIAL} & verifying old cert is rejected ==="; \
		$(DOCKER_RUN) sh -c "apk add --no-cache openssl bash >/dev/null && ./pki/scripts/revoke-cert.sh order-service $${OLD_SERIAL}"; \
		docker exec mtls-nginx-edge nginx -s reload; \
		$(NET_CLIENT) sh -c "apk add --no-cache curl >/dev/null && \
			curl -i -sS --cacert pki/out/trust/company-truststore.pem \
				--cert pki/out/clients/order-service/releases/$${OLD_SERIAL}/fullchain.pem \
				--key pki/out/clients/order-service/releases/$${OLD_SERIAL}/order-service.key \
				https://payments.internal.test/payments/status | head -n 1 || true"; \
	} > $(EVIDENCE_DIR)/06-zero-downtime-rotation.log 2>&1

	@echo "All Part 2 audit logs generated in $(EVIDENCE_DIR)/"

verify:
	@echo "Running strict regression assertions on $(EVIDENCE_DIR)/*.log"
	@grep -q "^-----BEGIN CERTIFICATE-----" $(EVIDENCE_DIR)/01-pki-and-eku.log
	@grep -q "TLS Web Server Authentication" $(EVIDENCE_DIR)/01-pki-and-eku.log
	@grep -q "TLS Web Client Authentication" $(EVIDENCE_DIR)/01-pki-and-eku.log
	@test $$(grep -c "HTTP/1.1 200 OK" $(EVIDENCE_DIR)/02-mtls-authn-vs-authz.log) -eq 3
	@test $$(grep -c "HTTP/1.1 403 Forbidden" $(EVIDENCE_DIR)/02-mtls-authn-vs-authz.log) -eq 2
	@grep -q "curl: (60)" $(EVIDENCE_DIR)/03-trust-stores.log
	@grep -q "HTTP/1.1 400 Bad Request" $(EVIDENCE_DIR)/03-trust-stores.log
	@grep -q "400 No required SSL certificate was sent" $(EVIDENCE_DIR)/04-broken-certificates.log
	@grep -q "curl: (58)" $(EVIDENCE_DIR)/04-broken-certificates.log
	@grep -q "error 23 at 0 depth lookup: certificate revoked" $(EVIDENCE_DIR)/05-crl-revocation.log
	@grep -q "X-Client-Cert-Serial: 1002" $(EVIDENCE_DIR)/06-zero-downtime-rotation.log
	@grep -q "X-Client-Cert-Serial: 1007" $(EVIDENCE_DIR)/06-zero-downtime-rotation.log
	@grep -q "HTTP/1.1 400 Bad Request" $(EVIDENCE_DIR)/06-zero-downtime-rotation.log
	@echo "ALL REGRESSION ASSERTIONS PASSED!"

clean:
	docker compose -p $(COMPOSE_PROJECT_NAME) -f $(COMPOSE_FILE) down -v 2>/dev/null || true
	rm -rf pki/out $(EVIDENCE_DIR)
