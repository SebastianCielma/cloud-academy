# Istio Part 2: Traffic Management, Canary Deployments and Gateway API

This project implements progressive deployment of Payment Service v2 using Istio Ambient Mesh, a dedicated waypoint proxy, and Gateway API HTTPRoute resources.

The project is isolated in namespace `istio-part2` and reuses the existing local Minikube cluster and Istio installation from Part 1. It does not modify `istio-demo` or remove existing Istio components.

## Architecture

```text
Client
  |
  v
API Gateway
  |
  v
Order Service
  |---> payment-service (stable Service) ---> payment-waypoint ---> payment-service-v1
  |                                         |--> payment-service-v2
  |
  `---> Inventory Service
```

Both Payment Service versions run simultaneously. The stable `payment-service` Kubernetes Service uses v1 endpoints as its fallback, while HTTPRoute rules attached to that Service instruct the waypoint to select either version at Layer 7.

Each application workload has a dedicated Kubernetes ServiceAccount. Applications expose HTTP endpoints and readiness/liveness probes. The Python application has no third-party runtime dependencies.

## Requirements

- A running Minikube profile named `istio-part1` with Istio Ambient components installed.
- A Kubernetes context named `istio-part1`.
- Docker, Minikube, kubectl and Python 3.10 or newer.
- Gateway API CRDs and the `istio-waypoint` GatewayClass.
- Resources for five application Pods and one waypoint proxy.

Defaults can be overridden with `ISTIO_PART2_PROFILE` and `ISTIO_PART2_CONTEXT`. All Kubernetes commands explicitly target the selected context.

## Build and Deploy

Run these commands from the project root:

```bash
./scripts/01-install-gateway-api.sh
./scripts/00-check-environment.sh
./scripts/02-build-images.sh
./scripts/03-deploy.sh
./scripts/04-verify-waypoint.sh
```

The Gateway API installation script only installs CRDs if they are absent. It does not delete or replace existing CRDs. If your cluster already has another suitable Gateway API version, that version remains in place.

The deployment script applies the namespace, ServiceAccounts, Deployments, Services, waypoint Gateway, and the initial v1 HTTPRoute. It performs a small initial functional check; the 1,000-request measurements are separate.

## Application Endpoints

| Service | Path | Response |
| --- | --- | --- |
| API Gateway | `GET /order` | Full application response |
| Order Service | `GET /order` | Payment and Inventory results |
| Payment v1 | `GET /payment` | `{"service":"payment-service","version":"v1","status":"success"}` |
| Payment v2 | `GET /payment` | `{"service":"payment-service","version":"v2","status":"success"}` |
| Inventory Service | `GET /inventory` | Stock availability |
| All workloads | `GET /healthz`, `GET /readyz` | Health status |
| All workloads | `GET /stats` | Process-local request counters |

When v2 receives `X-Lab-V2-Regression: true`, `GET /payment` returns HTTP 500 with a JSON error response. Version v1 ignores that header. The header is explicitly forwarded through API Gateway and Order Service.

The demo's `GET /payment` endpoint is read-only. It is not a real payment transaction.

## Weighted Canary Experiments

Run each stage separately so its results can be inspected and captured:

```bash
./scripts/05-run-weighted.sh 90-10
./scripts/05-run-weighted.sh 75-25
./scripts/05-run-weighted.sh 50-50
./scripts/05-run-weighted.sh 100-v2
```

Every stage performs 1,000 requests by default and saves a `.csv` file with every request, a `.json` summary, and a readable `.log` report. The report includes request counts, observed version shares, error rate, throughput, mean latency, p50, p95, and p99.

The validation allows four binomial standard deviations for the observed v2 count. This is a statistical diagnostic threshold, not a guarantee from Gateway API.

Reduce concurrency on a memory-constrained machine with `ISTIO_PART2_WORKERS=4`. Do not reduce `ISTIO_PART2_REQUESTS` below 1,000 for evidence intended to satisfy the assignment's weighted-routing requirement.

## Header-Based Routing

```bash
./scripts/06-run-header.sh
```

The header route uses an exact match for `x-release-channel: beta`, which sends requests to v2. All other requests use v1. Three checks cover no header, `beta`, and `stable`.

The matching header rule takes precedence over the unconditional fallback. For Gateway API HTTPRoute, match specificity determines precedence, followed by rule order for otherwise equivalent matches.

## Controlled Regression and Rollback

```bash
./scripts/07-run-rollback.sh
```

The script runs three successive measurements:

1. A healthy 75/25 canary with no regression header.
2. The same split with `X-Lab-V2-Regression: true`, causing v2 requests to return HTTP 500.
3. A routing-only rollback to 100% v1 with the same regression header.

Both Payment Deployments remain running. A shell exit trap restores the v1-only HTTPRoute even if a previous measurement fails. Deployment snapshots are saved before and after the sequence.

## Optional Traffic Mirroring

```bash
./scripts/08-run-mirroring-optional.sh
```

The optional HTTPRoute mirrors read-only `GET /payment` requests to v2 while returning v1's response to the client. The script checks v2 request counters before and after the run. Whether the filter is supported must be verified from the route status and actual results on the selected Istio/Gateway API versions.

Never apply this pattern to real state-changing payment endpoints without specific safeguards. Mirrored requests can duplicate side effects and the mirror's response is discarded.

## Collect Evidence

```bash
./scripts/09-collect-evidence.sh
./scripts/10-run-tests.sh
```

Experimental results are written to `reports/`. Optional screenshots belong in `evidence/`. The `docs/evidence-index.md` file maps assignment requirements to expected reports. These outputs are intentionally not prepopulated or fabricated.

The report files contain request identifiers. Generated CSV data is suitable for independent verification and further statistical analysis.

## Design Boundaries

- This project requires an L7 waypoint. Ztunnel alone does not evaluate HTTP headers or provide per-request weighted routing.
- The HTTPRoute is attached to the stable Kubernetes Service with `parentRefs.kind: Service`, not to an external ingress Gateway.
- Traffic is generated through a local port-forward to API Gateway. The important routed call is internal: Order Service to Payment Service, within Ambient Mesh.
- Python v1 and v2 images are built from the same educational codebase with separately tagged images and version settings. The regression is explicitly activated for testing.
- The mirroring exercise is optional and restricted to an idempotent read-only path.
- This is a local lab, not a production payment implementation.

## Documentation

- `docs/architecture.md`: network and routing architecture.
- `docs/requirements.md`: requirement-by-requirement implementation matrix.
- `docs/theory.md`: answers to all eight additional questions.
- `docs/statistics.md`: expected distributions, sampling variation and error-rate interpretation.
- `docs/evidence-index.md`: evidence files and experiment-to-report mapping.
- `docs/verification.md`: manual verification procedures and troubleshooting.

## Cleanup

```bash
./scripts/99-cleanup.sh
```

Cleanup removes only namespace `istio-part2`. It does not delete Gateway API CRDs, uninstall Istio or stop the Minikube profile used by Part 1.
