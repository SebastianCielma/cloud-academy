# Experiment 08: Cascading Failure and Timeout Protection

## Requirement

Demonstrate how a slow downstream Payment Service affects the application and evaluate the effect of a bounded HTTP timeout.

## Objective

Measure whether a 2-second Istio timeout limits client waiting time when Payment Service takes 5 seconds to respond.

## Configuration

| Parameter | Value |
|---|---|
| Kubernetes context | kind-istio-part3 |
| Namespace | istio-part3 |
| Mesh mode | Istio Ambient with waypoint |
| Application path | Client -> API Gateway -> Order -> Payment |
| Payment delay | 5000 ms |
| Configured timeout | 2 s |
| Client requests | 24 per scenario |
| Concurrency | 6 |
| Timeout manifest | manifests/ambient/10-payment-timeout.yaml |

## Test Procedure

1. Introduce a 5-second delay in Payment Service.
2. Send 24 requests without the additional timeout policy.
3. Record client response codes, latency, and throughput.
4. Enable the 2-second downstream HTTPRoute timeout.
5. Repeat the same 24-request workload.
6. Inspect Order Service and Payment Service counters.
7. Compare both scenarios.

Execution command:

    bash scripts/15-run-cascading-failure.sh

## Results

| Metric | Without timeout | With 2-second timeout |
|---|---:|---:|
| Requests | 24 | 24 |
| Concurrency | 6 | 6 |
| HTTP 200 | 24 | 0 |
| HTTP 502 | 0 | 24 |
| Error rate | 0% | 100% |
| Mean latency | 5020.171 ms | 2018.783 ms |
| p50 latency | 5020.015 ms | 2019.293 ms |
| p95 latency | 5023.095 ms | 2024.619 ms |
| p99 latency | 5024.685 ms | 2025.479 ms |
| Total elapsed time | 20.091 s | 8.079 s |
| Throughput | 1.195 req/s | 2.971 req/s |

## Scenario A: Slow Payment Without Timeout

All 24 requests completed with HTTP 200.

The mean response time was 5020.171 ms, closely matching the simulated 5-second Payment delay.

The complete workload took 20.091 seconds.

This shows how a slow dependency extends end-to-end request duration, even when the dependency eventually returns a successful response.

## Scenario B: Slow Payment With Timeout

All 24 requests completed with client-facing HTTP 502.

Order Service reported downstream HTTP 504 from Payment.

The mean response time decreased to 2018.783 ms, close to the configured 2-second timeout.

The complete workload took 8.079 seconds.

The measured mean latency decreased by approximately 59.8%.

## Backend Observations

After the timeout scenario, Payment Service reported:

| Counter | Value |
|---|---:|
| Active requests | 13 |
| Peak active requests | 18 |
| Requests received | 1020 |
| Requests completed | 1007 |

These counters suggest that some backend activity may continue after client-facing timeouts.

However, the counters are cumulative and are not isolated to the 24 test requests. They cannot establish exactly how many timed-out operations continued or completed.

## Analysis

The baseline scenario achieved 100% successful responses but required approximately five seconds per request.

The timeout scenario reduced waiting time to approximately two seconds but resulted in 100% client-visible failures.

Therefore, the timeout improved the bound on request duration, not successful request availability.

The increase in measured requests per second should not be interpreted as an increase in successful business operations. Timed-out requests terminate sooner, so the workload finishes faster despite failing.

Timeouts can reduce how long callers remain blocked by slow dependencies. However, they do not guarantee that backend work is cancelled.

The experiment demonstrates timeout-based isolation of waiting time. It does not independently prove that a complete cascading outage was prevented or that backend resource consumption decreased.

## Conclusion

A 2-second HTTPRoute timeout reduced mean client waiting time from approximately 5.02 seconds to 2.02 seconds.

This is a useful protection against prolonged waiting, but it also caused all requests to fail while Payment remained slower than the configured deadline.

Timeout values must balance acceptable response time with the expected behavior of downstream dependencies.

For operations with side effects, timeouts should be combined with carefully bounded retries and idempotency.

## Evidence

- reports/08-cascading-failure.log
- manifests/ambient/10-payment-timeout.yaml
- scripts/15-run-cascading-failure.sh
- tools/experiments.py
