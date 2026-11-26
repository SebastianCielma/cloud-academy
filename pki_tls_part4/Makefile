SHELL := /usr/bin/env bash -o pipefail
EVIDENCE_DIR := evidence

.PHONY: up evidence verify clean

up:
	./pki/scripts/setup-pki.sh
	docker compose -f infra/docker-compose.yml up -d

evidence:
	mkdir -p $(EVIDENCE_DIR)
	./scripts/test-ca-rotation-and-migration.sh > $(EVIDENCE_DIR)/01-ca-rotation-and-migration.log 2>&1
	./scripts/test-ca-compromise.sh > $(EVIDENCE_DIR)/02-ca-compromise.log 2>&1
	./scripts/test-troubleshooting.sh > $(EVIDENCE_DIR)/03-troubleshooting-8-cases.log 2>&1
	./scripts/test-cert-manager-failures.sh > $(EVIDENCE_DIR)/04-cert-manager-failures.log 2>&1
	./scripts/generate-inventory.sh > $(EVIDENCE_DIR)/05-certificate-inventory.md 2>&1
	./scripts/test-incident-0215.sh > $(EVIDENCE_DIR)/06-final-incident-0215.log 2>&1
	@echo "All 6 Part 4 evidence files generated in $(EVIDENCE_DIR)/"

verify:
	@echo "Running strict regression assertions on $(EVIDENCE_DIR)/*..."
	@grep -q "EXPECTED FAILURE" $(EVIDENCE_DIR)/01-ca-rotation-and-migration.log
	@grep -q "CloudAcademy Intermediate CA v2" $(EVIDENCE_DIR)/01-ca-rotation-and-migration.log
	@grep -q "rootv2-test.crt: OK" $(EVIDENCE_DIR)/01-ca-rotation-and-migration.log
	@grep -q "certificate revoked" $(EVIDENCE_DIR)/02-ca-compromise.log
	@grep -q "int-v2/ca.crt: OK" $(EVIDENCE_DIR)/02-ca-compromise.log
	@grep -q "certificate has expired" $(EVIDENCE_DIR)/03-troubleshooting-8-cases.log
	@grep -q "unsuitable certificate purpose" $(EVIDENCE_DIR)/03-troubleshooting-8-cases.log
	@grep -q "tlsv1 alert protocol version" $(EVIDENCE_DIR)/03-troubleshooting-8-cases.log
	@grep -q "CA / Infrastructure Layer" $(EVIDENCE_DIR)/04-cert-manager-failures.log
	@grep -q "payments-team" $(EVIDENCE_DIR)/05-certificate-inventory.md
	@grep -q "Verify return code: 0 (ok)" $(EVIDENCE_DIR)/06-final-incident-0215.log
	@echo "ALL PART 4 REGRESSION ASSERTIONS PASSED!"

clean:
	docker compose -f infra/docker-compose.yml down -v
	rm -rf .local
