# PKI & TLS — Part 2: Mutual TLS, Client Certificates & Trust Management

## Architecture Overview

```text
[mtls-order-service] ──(mTLS: client cert + server cert)──▶ [mtls-nginx-edge :443] ──(HTTP)──▶ [mtls-payment-service :5678]
                                                                    │
                                                         (HTTP :80 /crl/ CDP)
```

* **PKI Hierarchy:** 3-tier CA (`Internal Root CA` P-384 → `Intermediate CA` P-384 `pathlen:0` → `Leaf` P-256 90 days) + independent `Rogue External Root CA` for trust store isolation tests.
* **Authentication (AuthN) vs Authorization (AuthZ):**
  * `GET /payments/status`: accessible to any client holding a valid certificate signed by the company CA (`order-service`, `inventory-service`, `unauthorized-client`).
  * `POST /payments/charge`: restricted via Nginx `map $ssl_client_s_dn $client_cn` exclusively to `CN=order-service` (`HTTP 200`); all other authenticated clients receive `HTTP 403 Forbidden`.
* **Revocation (CRL):** Signed CRL published via HTTP CDP (`http://payments.internal.test/crl/intermediate.crl.pem`) and enforced on port `443` (`ssl_crl`), contrasted against port `8445` (no CRL check) and client-side `openssl verify -crl_check`.

## Quick Start

```bash
make evidence   # Generates PKI, starts containers, runs all 6 audit suites into evidence/
make down       # Stops and removes containers and networks
```

## Broken Certificate Scenarios — Root Cause & Diagnostics

| Scenario | Rejecting Side | Root Cause | Diagnostic Command / Evidence |
| :--- | :--- | :--- | :--- |
| **Missing Client Cert** | Server (Nginx `400`) | `ssl_verify_client on` requires a client certificate during TLS handshake. | `curl -v --cacert company-truststore.pem https://payments.internal.test/payments/status` (`04-broken-certificates.log`) |
| **Expired Client Cert** | Server (Nginx `400`) | Current time is outside the certificate `Not Before` / `Not After` validity window. | `openssl x509 -in expired-client.crt -noout -dates` |
| **Wrong EKU (`serverAuth`)** | Server (Nginx `400`) | Certificate lacks `TLS Web Client Authentication` (`clientAuth`) in `Extended Key Usage`. | `openssl x509 -in wrong-eku-client.crt -noout -ext extendedKeyUsage` |
| **Missing Intermediate (Client)** | Server (Nginx `400`) | Client sent only leaf `.crt` without `intermediate-ca.crt`; Nginx trust store only holds `Root CA`. | `openssl s_client -connect payments.internal.test:443 -cert leaf.crt -key client.key` |
| **Missing Intermediate (Server :8443)** | Client (`curl: 60`) | Server sent leaf `.crt` instead of `fullchain.pem` (`leaf + intermediate`). | `openssl s_client -connect payments.internal.test:8443 -showcerts` |
| **Wrong Server SAN (:8444)** | Client (`curl: 60`) | Requested hostname `payments.internal.test` is absent from certificate `Subject Alternative Name`. | `openssl x509 -in wrong-san.crt -noout -ext subjectAltName` |
| **Cert / Private Key Mismatch** | Client (`curl: 58`) | Public key modulus/point in certificate does not match the provided private key file. | Compare `openssl x509 -in cert.crt -pubkey -noout` with `openssl pkey -in key.key -pubout` |
| **Untrusted CA (Rogue Trust Store)** | Client (`curl: 60`) / Server (`400`) | Issuer signature cannot be chained back to any Root CA in the peer's Trust Store. | `openssl verify -CAfile truststore.pem -untrusted intermediate-ca.crt cert.crt` |
| **Revoked Certificate (CRL)** | Server (`400`) / Client (`verify error 23`) | Certificate serial number is listed with status `R` in the CA's signed CRL. | `openssl crl -in intermediate.crl.pem -noout -text` |

## Lifecycle Impact Matrix

* **Rotating Cert + Matching Private Key (`make evidence` step 6):** Zero-downtime atomic swap (`mv`); new TLS connections immediately present the new serial (`1002` → `1007`).
* **Changing Only Private Key (without re-issuing cert):** Immediate handshake failure (`key values mismatch`), as the signature cannot be verified by the old public key in the certificate.
* **Changing Root CA Trust:** All leaf/intermediate certificates signed by the old Root CA fail validation immediately until the new Root CA is distributed to both server and client Trust Stores.
