SHELL := /usr/bin/env bash -o pipefail
EVIDENCE_DIR := evidence

.PHONY: evidence verify clean

evidence:
	./scripts/collect-evidence.sh

verify:
	@echo "Running strict regression assertions on $(EVIDENCE_DIR)/*.log..."
	@grep -q "newOrder" $(EVIDENCE_DIR)/01-step-ca-acme.log
	@grep -q "cert-manager-webhook" $(EVIDENCE_DIR)/02-cert-manager-setup.log
	@grep -q "certificates.cert-manager.io" $(EVIDENCE_DIR)/02-cert-manager-setup.log
	@grep -q "api-service" $(EVIDENCE_DIR)/03-certificates-and-https.log
	@grep -q "payments-service" $(EVIDENCE_DIR)/03-certificates-and-https.log
	@grep -q "no such host" $(EVIDENCE_DIR)/04-failure-scenarios.log
	@grep -q "unknown authority" $(EVIDENCE_DIR)/04-failure-scenarios.log
	@grep -q "fail-challenge-cert" $(EVIDENCE_DIR)/04-failure-scenarios.log
	@grep -q "AFTER ROTATION:" $(EVIDENCE_DIR)/05-forced-rotation.log
	@grep -q "AUTOMATIC RENEWAL DETECTED" $(EVIDENCE_DIR)/06-automatic-renewal.log
	@grep -q "\[ALERT\]" $(EVIDENCE_DIR)/07-monitoring-alert.log
	@echo "ALL PART 3 REGRESSION ASSERTIONS PASSED!"

clean:
	kind delete cluster --name pki-acme-lab
	rm -rf .local
