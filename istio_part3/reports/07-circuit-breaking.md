# Experiment 07: Circuit Breaking Under High Concurrency

## Requirement

Configure Istio circuit breaking and demonstrate its effect on Payment Service under high client concurrency.

## Objective

Determine whether a DestinationRule connection pool policy limits the traffic forwarded to Payment Service.

## Environment and Configuration

| Parameter | Value |
|---|---|
| Kubernetes context | kind-istio-part3 |
| Namespace | istio-part3 |
| Mesh mode | Istio Ambient with waypoint |
| Policy resource | DestinationRule |
| Manifest | manifests/ambient/30-payment-circuit-breaker.yaml |
| Target | Payment Service |
| Client requests | 70 per scenario |
| Client concurrency | 15 |

### Connection Pool Configuration

| Setting | Value |
|---|---:|
| maxConnections | 1 |
| http1MaxPendingRequests | 1 |
| http2MaxRequests | 1 |
| maxRequestsPerConnection | 1 |

The DestinationRule also contains outlier detection settings.

## Test Procedure

1. Send 70 requests with concurrency 15 without a circuit-breaking policy.
2. Record client response codes and latency.
3. Apply the Payment Service DestinationRule.
4. Repeat the same workload.
5. Read Payment Service counters after the second test.
6. Compare successful responses, errors, and backend requests received.

Execution command:

    bash scripts/13-run-overload.sh

## Results

| Metric | Without circuit breaking | With circuit breaking |
|---|---:|---:|
| Requests | 70 | 70 |
| Successful requests | 70 | 13 |
| Failed requests | 0 | 57 |
| HTTP 200 | 70 | 13 |
| HTTP 502 | 0 | 57 |
| Error rate | 0% | 81.429% |
| Average latency | 1150.979 ms | 1171.666 ms |
| p50 latency | 1029.925 ms | 1028.819 ms |
| p95 latency | 2054.786 ms | 2470.424 ms |
| p99 latency | 2121.743 ms | 2862.300 ms |
| Throughput | 10.601 req/s | 10.633 req/s |

## Backend Observations

With the circuit-breaking policy active:

| Observation | Value |
|---|---:|
| Client requests | 70 |
| Successful client responses | 13 |
| Failed client responses | 57 |
| Payment requests received | 13 |
| Reported peak active requests | 11 |

The failed client responses contained downstream_status 503, which was propagated through the application as HTTP 502.

The Payment request counter increased by only 13, matching the number of successful client requests.

## Analysis

Without the DestinationRule, the application completed all 70 requests successfully.

After enabling restrictive connection pool limits, 57 of 70 requests failed and only 13 requests reached Payment Service.

The results support the conclusion that traffic was limited before reaching the backend.

This behavior protects the dependency from receiving the full offered workload, but it also reduces the number of successful client requests.

The reported peak_active counter should not be interpreted as a direct measurement of the Envoy connection pool limit. The application counter and the proxy connection limits measure different properties.

The observed error rate of 81.429% does not represent improved client availability. It demonstrates the enforcement of restrictive overload protection.

The test does not isolate the contribution of each individual connection pool parameter, and it does not independently demonstrate outlier ejection.

## Conclusion

The Istio DestinationRule limited traffic forwarded to Payment Service during a high-concurrency workload.

With the policy enabled, Payment received only 13 of 70 offered client requests.

Circuit breaking is a mechanism for protecting backend capacity, not a guarantee that every client request will succeed.

Production limits must be selected based on actual service capacity and acceptable rejection rates.

## Evidence

- reports/07-overload.log
- manifests/ambient/30-payment-circuit-breaker.yaml
- scripts/13-run-overload.sh
- tools/experiments.py

## Additional Verification: Sidecar Mode

The circuit-breaking experiment was repeated in a separate namespace using Istio sidecar proxies.

Policy: manifests/sidecar/30-payment-circuit-breaker.yaml

| Metric | Without limits | With limits |
|---|---:|---:|
| Client requests | 70 | 70 |
| Concurrency | 15 | 15 |
| HTTP 200 | 70 | 24 |
| HTTP 502 | 0 | 46 |
| Error rate | 0% | 65.714% |
| Average latency | 800.496 ms | 911.708 ms |
| p95 latency | 1811.278 ms | 2282.115 ms |
| p99 latency | 2039.816 ms | 2864.724 ms |
| Throughput | 17.847 req/s | 13.046 req/s |

### Interpretation

Without connection limits, all 70 requests succeeded.

With the DestinationRule active, 46 requests failed with client-facing HTTP 502. The application responses identified downstream HTTP 503 failures.

The result demonstrates a substantial change in request handling under the configured connection limits.

Unlike the Ambient experiment, this Sidecar measurement does not include a before-and-after Payment request counter. Therefore, it does not independently prove that every failed request was rejected by the proxy before reaching the backend.

The Ambient and Sidecar results should not be used as a direct performance ranking because they were obtained in separate workloads and deployment configurations.

### Additional Evidence

- reports/07-overload-sidecar.log
- manifests/sidecar/30-payment-circuit-breaker.yaml
- scripts/14-run-sidecar-overload.sh
