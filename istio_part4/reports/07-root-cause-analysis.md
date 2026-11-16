# Experiment 07 — Production Incident RCA

## Summary

A controlled incident was introduced into the Istio Ambient environment.
Three independent configuration faults affected traffic routing and service communication.

## Incident 1 — Incorrect Canary Weights

**Expected:** Payment v1 90%, Payment v2 10%.

**Fault:** HTTPRoute weights were changed to 50/50.

**Measured baseline:** 183 v1 requests, 17 v2 requests out of 200.

**Measured incident:** 99 v1 requests, 101 v2 requests out of 200.

**Impact:** Payment v2 received 50.5% of traffic instead of the intended 10%.
All 200 incident requests returned HTTP 201, so availability checks alone would not detect this routing fault.

**Root cause:** Incorrect HTTPRoute backend weights.

**Recovery:** Reapplied the original 90/10 HTTPRoute.

## Incident 2 — Incorrect ServiceAccount

**Expected identity:** cluster.local/ns/istio-part4/sa/order-service

**Fault:** The Order Service deployment was changed to use order-incident.

**Observed impact:**
- Order to Payment: HTTP 403, RBAC: access denied
- API Gateway to Order: HTTP 502
- Inventory to Payment: HTTP 403
- Unknown Client to Payment: HTTP 403

**Root cause:** Workload identity no longer matched the waypoint AuthorizationPolicy.

**Recovery:** Restored serviceAccountName: order-service and completed the rollout.

**Verified after recovery:** Order to Payment returned HTTP 200; unauthorized clients remained blocked.

## Incident 3 — Missing Waypoint Binding

**Expected:** payment-service carries istio.io/use-waypoint=payment-waypoint.

**Fault:** The waypoint label was removed from the Payment Service.

**Observed impact:**
- Order to Payment: ConnectionResetError
- API Gateway to Order: RemoteDisconnected
- Other clients: transport connection errors
- ztunnel: connection closed due to policy rejection: allow policies exist, but none allowed

**Root cause:** Traffic bypassed the waypoint while the destination ztunnel L4 policy still allowed only the waypoint identity.

**Recovery:** Restored the payment-service waypoint label.

**Verified after recovery:** Order to Payment returned HTTP 200; Inventory and Unknown Client returned HTTP 403.

## Security Assessment

The incident was resolved without removing Default Deny or granting broader access.
The L4 and L7 authorization boundaries remained intact.

## Recovery Verification

- Order ServiceAccount: order-service
- Payment waypoint binding: restored
- HTTPRoute backend weights: v1=90, v2=10
- HTTPRoute Accepted, ResolvedRefs and ResolvedWaypoints: True
- All seven deployments: Ready
- API Gateway to Order: HTTP 200
- Order to Payment: HTTP 200
- Inventory to Payment: HTTP 403
- Unknown Client to Payment: HTTP 403

## Preventive Actions

1. Review HTTPRoute changes and monitor traffic split by version.
2. Validate ServiceAccount identities during deployments.
3. Detect missing istio.io/use-waypoint labels.
4. Monitor HTTP 403, HTTP 5xx and connection resets separately.
5. Keep known-good manifests and tested rollback commands.
6. Add deployment checks for waypoint and authorization-policy compatibility.

## Limitations

The tests were performed on a local kind cluster.
The ServiceAccount fault and waypoint-binding fault were introduced and measured separately, rather than simultaneously.
Transport connection errors during the waypoint fault were not HTTP 503 responses.
The final post-recovery traffic-distribution measurement is recorded separately.

## Final Canary Recovery Measurement

The same test procedure was used across all three phases:
200 POST /payments requests per phase.

| Metric | Baseline | Incident | Recovered |
|---|---:|---:|---:|
| HTTP 201 v1 | 183 | 99 | 185 |
| HTTP 201 v2 | 17 | 101 | 15 |
| v1 traffic share | 91.50% | 49.50% | 92.50% |
| v2 traffic share | 8.50% | 50.50% | 7.50% |
| HTTP errors | 0 | 0 | 0 |

The recovered traffic split is consistent with the configured
90/10 canary weights.

All 200 post-recovery requests succeeded with HTTP 201.

The ServiceAccount and waypoint-binding failures were also repaired.
The final authorization checks confirmed HTTP 200 for Order and
HTTP 403 for unauthorized Inventory and Unknown Client workloads.

The routing fault, ServiceAccount fault and waypoint-binding fault
were investigated in controlled stages. These measurements do not
represent a single simultaneous load test of all faults.
