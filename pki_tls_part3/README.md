# PKI & TLS — Part 3: Automated Certificate Management with ACME & cert-manager

## Architecture Overview

```text
[step-ca :9000 (Private ACME)] ◀──(HTTPS: newOrder / finalize)── [cert-manager Controller]
        │                                                                 │
        └──(HTTP :80 /.well-known/acme-challenge/<token>)──▶ [ingress-nginx] ──▶ [HTTP-01 Solver Pod]
                                                                  │
                                                           (TLS Secret: tls.crt / tls.key)
                                                                  ▼
                                                     [api.internal.test / payments.internal.test]
```

* **Private ACME Server (`step-ca`):** Local 2-tier PKI with ACME provisioner (`acme-prov`) tuned for short-lived test certificates (`min: 5m`, `default: 1h`, `max: 24h`).
* **Real HTTP-01 Validation (No Public Domain):** CoreDNS inside `kind` resolves `api.internal.test` and `payments.internal.test` to `ingress-nginx-controller` ClusterIP, allowing `step-ca` to perform genuine RFC 8555 HTTP-01 challenges.
* **Two HTTPS Services:** `api-service` (`api.internal.test`) and `payments-service` (`payments.internal.test`) backed by `Certificate` resources with `duration: 1h`, `renewBefore: 57m`, and `rotationPolicy: Always`.

## ACME Challenge Comparison

| Challenge | Validation Method | Wildcard Support | Best Use Case |
| :--- | :--- | :--- | :--- |
| **HTTP-01** *(implemented)* | Serves token at `http://<domain>/.well-known/acme-challenge/<token>` on port 80. | No | Standard web apps behind Ingress / Reverse Proxy. |
| **DNS-01** | Creates TXT record at `_acme-challenge.<domain>` via DNS provider API. | **Yes** (`*.domain`) | Internal services without port 80 or wildcard certificates. |
| **TLS-ALPN-01** | Serves self-signed cert with `acme-tls/1` ALPN extension on port 443. | No | Environments where port 80 is blocked, only 443 is open. |

## Issuer vs ClusterIssuer

* **`Issuer`:** Namespace-scoped resource — can only issue certificates within its own namespace (used here for isolated failure tests in `apps`).
* **`ClusterIssuer`:** Cluster-scoped resource — shared across all namespaces (used here as `step-ca-acme` for cluster-wide ACME automation).

## Evidence & Verification Pipeline

```bash
make evidence   # Captures all 7 audit logs into evidence/
make verify     # Runs strict regression assertions on evidence/*.log
make clean      # Deletes kind cluster (pki-acme-lab) and .local/ artifacts
```

| Log File | Verified Capability |
| :--- | :--- |
| `01-step-ca-acme.log` | ACME directory endpoints (`newNonce`, `newAccount`, `newOrder`) & active ACME orders. |
| `02-cert-manager-setup.log` | `cert-manager` controller, cainjector, webhook, CRDs, and Ready `ClusterIssuer`. |
| `03-certificates-and-https.log` | Issued `Certificate`/`Secret` objects and live HTTPS responses for `api` & `payments`. |
| `04-failure-scenarios.log` | Wrong CA URL (`no such host`), missing trust bundle (`unknown authority`), and failed HTTP-01 challenge (`fail-challenge.internal.test`). |
| `05-forced-rotation.log` | Forced re-issuance of `payments-internal-cert` with new serial & new ECDSA key pair (`rotationPolicy: Always`). |
| `06-automatic-renewal.log` | Automatic renewal of short-lived `api-internal-cert` and hot-reload in `ingress-nginx` without pod restart. |
| `07-monitoring-alert.log` | Expiry monitoring script triggering `[ALERT]` when remaining lifetime drops below threshold. |
