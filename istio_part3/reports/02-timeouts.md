# Experiment 02: Payment Service Timeout

## Requirement

Configure a 2-second mesh timeout for a Payment Service request delayed by 5 seconds. Observe the client response and determine whether backend processing can continue after the timeout.

## Objective

Verify that Istio limits how long the caller waits for a slow dependency.

## Configuration

| Parameter | Value |
|---|---|
| Kubernetes context | kind-istio-part3 |
| Namespace | istio-part3 |
| Service mesh | Istio Ambient with waypoint |
| Policy resource | HTTPRoute |
| Manifest | manifests/ambient/10-payment-timeout.yaml |
| Route | /payment/probe |
| Simulated backend delay | 5000 ms |
| Request timeout | 2 s |
| Backend request timeout | 2 s |
| Client requests | 1 |

The HTTPRoute is attached to payment-service and processed through the waypoint.

The request enters through API Gateway, reaches Order Service, and then calls Payment Service.

## Test Procedure

1. Configure the Payment Service waypoint.
2. Apply the HTTPRoute with 2-second timeouts.
3. Record Payment Service counters.
4. Send one GET request to /order/payment-only with X-Lab-Payment-Delay-Ms: 5000.
5. Measure client latency and HTTP response.
6. Read Payment Service counters immediately after the response.
7. Wait 5.2 seconds and read the counters again.
8. Remove the temporary HTTPRoute.

Command used:

    bash scripts/07-run-timeouts.sh

## Expected Behavior

The client should receive a timeout-related failure after approximately 2 seconds, rather than waiting for the full 5-second backend delay.

Backend processing may continue even after the caller stops waiting.

## Observed Results

| Metric | Observation |
|---|---|
| Requests | 1 |
| Client HTTP status | 502 |
| Downstream Payment status reported by Order | 504 |
| Client latency | 2036.620 ms |
| Configured timeout | 2000 ms |
| Difference from timeout | 36.620 ms |
| Client failures | 1 of 1 |

The client-facing response reported dependency payment and downstream_status 504.

## Backend Counters

| Counter | Before | Immediately after | After 5.2 s |
|---|---:|---:|---:|
| Probe requests received | 120 | 121 | 121 |
| Completed requests | 269 | 271 | 274 |
| Active requests | 1 | 2 | 1 |

## Analysis

The observed client latency was 2036.620 ms. This is close to the configured 2-second timeout and substantially lower than the simulated 5-second Payment delay.

The timeout occurred on the downstream Payment call. Order Service observed HTTP 504, while the client received HTTP 502 from the application request chain.

The Payment counters show one additional probe request. Active requests increased immediately after the client-facing timeout and decreased after the waiting period.

These observations are consistent with backend processing continuing after the caller timed out.

However, completed-request counters are shared with other HTTP operations, including statistics requests. They do not uniquely identify completion of the delayed probe. Therefore, continued execution is supported by the observations but not conclusively established by this measurement alone.

A request-specific completion event would provide stronger evidence.

This experiment uses one deliberately delayed request. It validates timeout behavior but does not provide a statistically meaningful performance distribution.

## Conclusion

The Istio HTTPRoute timeout successfully limited the client-facing waiting time to approximately 2 seconds despite a 5-second backend delay.

A timeout does not by itself guarantee cancellation of backend work.

For operations with side effects, timeout handling must be considered together with retries and idempotency.

## Evidence

- reports/02-timeouts.log
- manifests/ambient/10-payment-timeout.yaml
- scripts/07-run-timeouts.sh
- tools/experiments.py
