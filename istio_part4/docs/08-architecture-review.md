# Istio Part 4 — Architecture Review

## 1. Scope and topology

The experiment uses Istio 1.31.4 in Ambient mode on a local, single-node kind cluster. The application comprises API Gateway, Order Service, Inventory Service, and Payment Service. Payment has two versions for canary traffic splitting. The `istio-part4` namespace hosts a dedicated Payment waypoint, and `istio-egress` hosts a waypoint for the selected external host `httpbin.org`.

The main request path is `api-gateway -> order-service -> payment-service`. Order also calls Inventory. Ambient ztunnel handles workload connectivity, mTLS identities and L4 authorization. The Payment waypoint applies HTTP-level authorization, JWT authentication and routing. Workload identity is expressed through Kubernetes ServiceAccounts and SPIFFE principals. A `ServiceEntry` represents the selected external service.

## 2. Security and least privilege

The initial baseline demonstrated that Order, Inventory and an unknown client could all call Payment successfully (HTTP 200). A selector-based `AuthorizationPolicy` with `action: ALLOW` and no rules denied access at L4. On this setup, that denial surfaced as connection termination and HTTP 503 at the calling proxy, not as an HTTP 403 response from the Payment application.

A first attempt at an L4 rule allowing only `order-service` did not restore communication. Traffic passed through the Payment waypoint, so the destination ztunnel observed the waypoint's identity as its direct peer. The corrected design permits the waypoint ServiceAccount at L4, while an L7 policy attached to the Payment Service permits only the Order ServiceAccount for approved operations. The final identity checks returned HTTP 200 for Order and HTTP 403 (`RBAC: access denied`) for Inventory and the unknown client.

At L7, `GET /health` and `POST /payments` were allowed for Order. `GET /payments/{id}` additionally required a valid JWT with role `payment-reader`; other paths and methods were denied. Seven HTTP authorization checks matched expectations. The JWT evaluation matched all six checks: valid token 200; invalid signature 401; expired token 401; missing token 403; incorrect role 403; and an unauthenticated health request 200. These controls complement, rather than replace, application-level authorization, input validation and secure business logic.

## 3. Egress security and limitations

Before egress configuration, DNS resolution worked and external requests were possible. A `ServiceEntry` for `httpbin.org`, an egress waypoint and an L7 policy allowed Order `GET /get` (HTTP 200), while denying `POST /post` and `GET /headers` (HTTP 403, `RBAC: access denied`). All three measured HTTP cases matched expectations. Ambient DNS capture was enabled and produced synthetic addresses for the ServiceEntry host.

This is evidence of policy enforcement for one registered external host; it is **not** proof of mandatory, cluster-wide egress restriction. The cluster used kindnet and no Kubernetes `NetworkPolicy` resources were present. NetworkPolicy enforcement and prevention of direct/bypass connections were not demonstrated. A production environment should evaluate a capable CNI, network-layer egress restrictions and an approved gateway path, then verify attempts to bypass that path.

## 4. Resilience and traffic management

A Gateway API `HTTPRoute` routed Payment traffic through the waypoint with nominal weights of 90% to v1 and 10% to v2. Each measurement used 200 `POST /payments` requests and collected the backend-reported version.

| Phase | HTTP 201 v1 | HTTP 201 v2 | v1 share | v2 share | Errors |
|---|---:|---:|---:|---:|---:|
| Before incident (90/10) | 183 | 17 | 91.50% | 8.50% | 0 |
| Incident (50/50) | 99 | 101 | 49.50% | 50.50% | 0 |
| Recovered (90/10) | 185 | 15 | 92.50% | 7.50% | 0 |

The incident increased observed v2 traffic from 8.5% to 50.5%. All requests still succeeded with HTTP 201; basic availability monitoring therefore failed to reveal the routing misconfiguration. The restored 90/10 routing produced 7.5% observed v2 traffic over 200 requests, consistent with probabilistic load balancing. The experiment did not establish load-capacity or high-availability properties.

## 5. Observability and diagnostics

Envoy access logs from the Payment waypoint showed successful `GET /health` requests with `200 via_upstream` and rejected requests with `403 rbac_access_denied_matched_policy[none]`. ztunnel logs recorded SPIFFE workload identities, source and destination workloads, connection direction, and transfers through the waypoint. `istioctl proxy-status` showed the two waypoints and ztunnel connected to istiod.

A deliberately empty `unavailable-service` returned HTTP 503 with `no healthy upstream`; its EndpointSlice showed no ready endpoints. No corresponding Payment waypoint access-log entry was captured for that request, so the evidence does not establish which proxy emitted the 503. During the waypoint-binding incident, clients observed `ConnectionResetError` or `RemoteDisconnected`, and ztunnel logged `connection closed due to policy rejection: allow policies exist, but none allowed`. Those errors were transport failures, not measured HTTP 503 client responses. A ztunnel HBONE `401 Unauthorized` log is not equivalent to a user's JWT failure.

Logs and proxy-status diagnostics were measured. A full production monitoring stack with persistent Prometheus metrics, Grafana dashboards, distributed tracing, alert evaluation and retention was not verified in these experiments. These are recommended follow-up controls.

## 6. Production incident and root causes

Three faults were introduced and investigated in controlled stages rather than in one simultaneous load test.

1. **Routing:** The Payment HTTPRoute weights changed from 90/10 to 50/50. The actual v2 share rose to 50.5% without HTTP errors. The known-good route manifest restored the intended weights.
2. **Workload identity:** Order's ServiceAccount changed from `order-service` to `order-incident`. The Payment waypoint returned HTTP 403, and API Gateway returned HTTP 502 because its Order dependency failed. Restoring the original ServiceAccount and completing the rollout recovered HTTP 200 for Order.
3. **Waypoint binding:** Removing `istio.io/use-waypoint=payment-waypoint` from the Payment Service caused calls to bypass the waypoint and hit destination L4 authorization directly. ztunnel rejected the connections. Restoring the Service label recovered the permitted path while keeping unauthorized clients denied.

Recovery did not require disabling Default Deny, removing JWT checks or broadening access to all workloads. After recovery all seven deployments were ready, the HTTPRoute reported `Accepted=True`, `ResolvedRefs=True` and `ResolvedWaypoints=True`, and Order/Inventory/unknown access again returned 200/403/403 respectively.

## 7. Performance and resource costs

Ambient architecture avoids a per-application-pod sidecar but introduces node-level ztunnel and optional shared waypoints. The extra network hop and policy evaluation can add latency and CPU/memory usage. This Part 4 exercise did not collect controlled latency distributions, CPU/memory profiles or waypoint saturation measurements. No numeric performance improvement or cost saving can be inferred from these results. A production review should compare p50/p95/p99 request latency, error rates, proxy resource utilization and cost under representative concurrency.

## 8. Operational risks and rollback

Risks include overbroad ALLOW policies, missing waypoint labels, ServiceAccount drift, unreviewed HTTPRoute weights, stale JWT signing keys and external egress bypass. Recommended preventive controls are Git-reviewed manifests, pre-deployment identity and routing checks, alerts for HTTP 403/5xx/transport errors, version-split metrics, policy testing, and key-rotation procedures.

Tested rollback actions include restoring Order's original ServiceAccount, restoring the Payment Service waypoint label, and reapplying the 90/10 HTTPRoute. The tested recovery verifies function, but it does not validate disaster recovery, multi-node failure tolerance or zero-downtime rollout under production load.

## 9. Evidence index

- `reports/01-baseline-terminal.log` — unrestricted initial access.
- `reports/01-default-deny-terminal.log` — deny, correction and least-privilege recovery.
- `reports/02-service-identity-terminal.log` — authorized and unauthorized workload identities.
- `reports/03-http-authorization-terminal.log` — seven HTTP method/path checks.
- `reports/04-jwt-terminal.log` — six JWT and health regression checks.
- `reports/05-egress-baseline-terminal.log` and `reports/05-egress-terminal.log` — egress before/after controls.
- `reports/06-observability-terminal.log` — waypoint/ztunnel access and diagnostic logs, and no-backend case.
- `reports/07-canary-baseline-terminal.log`, `reports/07-canary-incident-terminal.log`, `reports/07-canary-recovered-terminal.log` — three measured routing phases.
- `reports/07-serviceaccount-incident-terminal.log`, `reports/07-waypoint-incident-terminal.log`, associated recovery logs, and `reports/07-final-recovery-terminal.log` — incident root causes and verification.
- `reports/07-root-cause-analysis.md` — consolidated incident RCA.

## 10. Final assessment

The experiment demonstrates practical, layered security and fault diagnosis in a local Istio Ambient deployment: L4 identity constraints, L7 method/path authorization, JWT policy checks, selected-host egress authorization, waypoint diagnostics and measured canary rollback. The findings are bounded by the local one-node environment and the explicit tests above. For production, add tested network-layer egress enforcement, HA, SLO-based alerting, tracing, metric retention and performance/capacity measurements.
