# Verification Runbook

## Prerequisites

The previous Istio Part 1 environment is expected to provide a running Minikube profile called `istio-part1`, an Istio control plane, Istio CNI, and ztunnel. The Part 2 project must not recreate the entire cluster or modify Part 1 resources.

Use `scripts/01-install-gateway-api.sh` to install CRDs only when missing, then run `scripts/00-check-environment.sh`. If the existing cluster uses a different context or profile, set `ISTIO_PART2_CONTEXT` and `ISTIO_PART2_PROFILE` appropriately.

## Application Readiness

Run `scripts/02-build-images.sh` and `scripts/03-deploy.sh`. Verify five application Deployments are available and the waypoint Gateway has `Programmed=True`. Run `scripts/04-verify-waypoint.sh` to inspect the Service label and HTTPRoute conditions.

The waypoint is a Gateway API resource, not an Istio ingress gateway. Its HBONE listener is for in-mesh processing and is not a public HTTP entrypoint.

## Proof of Actual Waypoint Routing

The stable `payment-service` selects only v1 Pods at the Kubernetes level. Therefore, when the HTTPRoute is set to a nonzero v2 weight, observing v2 responses through `GET /order` is evidence that L7 routing, rather than the stable Service's fallback selector, selected v2.

The strongest check combines Gateway `Programmed=True`, HTTPRoute `Accepted=True`, HTTPRoute `ResolvedRefs=True`, and observed v2 response counts.

## Weighted Routing

Run the 90/10, 75/25, and 50/50 stages individually. Each stage generates at least 1,000 requests by default and retains raw CSV data. Compare actual percentages and expected binomial variability using `docs/statistics.md`.

Run 100% v2 only after the prior stages succeed. Each stage is independent; later experiments change the same HTTPRoute object.

## Header-Based Routing

The beta match is checked first, followed by an unconditional v1 default. Confirm both positive and negative cases. A beta header can originate at the client and is forwarded through the API Gateway and Order Service to the Payment Service's stable destination.

In the Gateway API specification, more specific matches have priority over less specific matches; rule order acts as a tie-breaker when match specificity is equivalent. The header match has greater specificity than the fallback rule.

## Rollback

Run `scripts/07-run-rollback.sh`. Compare three reports: healthy 75/25, failing v2 under a test header, and zero-error v1-only routing under the same header. The script saves snapshots of both Payment Deployments. The rollback is performed by applying a different HTTPRoute manifest, with no Deployment deletion or rollout restart.

## Optional Mirroring

Mirroring is isolated in its own manifest and is not enabled by default. Verify filter support from the HTTPRoute status and actual v2 request counters. Do not rely solely on a successful `kubectl apply` result. The client must continue observing v1, and v2 must record additional read-only requests.

The mirroring example is for demonstration only and must not be used with production payment side effects.

## Troubleshooting

| Symptom | Likely cause | First check |
| --- | --- | --- |
| All requests reach v1 in a weighted stage | Waypoint or route not used | Service label and HTTPRoute conditions |
| Gateway is not Programmed | Waypoint provisioning issue | Gateway status and waypoint Pod |
| HTTPRoute Accepted is False | Invalid parentRef or unsupported rule | HTTPRoute status conditions |
| ResolvedRefs is False | Missing backend Service or invalid port | Versioned Services and route backendRefs |
| ImagePullBackOff | Image not loaded into Minikube | Profile and image tags |
| Endpoint unavailable | Application not ready | Deployment status and Pod logs |
| Port-forward cannot start | Local port already in use | TCP port 18080 or 18081 |
| Distribution varies from target | Sampling variation or config propagation | Request count, route status, sample size |
| Mirroring count remains zero | Unsupported filter or waypoint mismatch | HTTPRoute conditions and logs |

## Cleanup

Run `scripts/99-cleanup.sh` only when Part 2 experiments are complete. This removes namespace `istio-part2` and keeps the underlying Istio installation and Part 1 environment unchanged.
