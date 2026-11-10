# Experiment 03: Inventory Service Retries

## Requirement

Handle intermittent HTTP 503 responses from Inventory Service using bounded retries.

## Objective

Determine whether a retry policy reduces client-facing errors and identify the cost in response latency.

## Configuration

| Setting | Value |
|---|---|
| Kubernetes | kind-istio-part3 |
| Mesh | Istio Ambient with waypoint |
| Policy | Gateway API HTTPRoute |
| Manifest | manifests/ambient/20-inventory-retries.experimental.yaml |
| Retried status | HTTP 503 |
| Retry attempts | 2 |
| Retry backoff | 50 ms |
| Request timeout | 4 s |
| Backend request timeout | 1 s |
| Requests per scenario | 60 |
| Concurrency | 4 |
| Fault simulation | Inventory fails every third request |

## Procedure

1. Remove previous test routing policies.
2. Send 60 requests with periodic Inventory HTTP 503 failures.
3. Measure client errors and response latency.
4. Assign Inventory Service to the waypoint.
5. Apply the HTTPRoute retry policy.
6. Repeat the 60-request workload.
7. Compare availability and latency.
8. Remove the experimental routing policy.

Execution command:

    bash scripts/08-run-retries.sh

## Results

| Metric | Without retries | With retries |
|---|---:|---:|
| Requests | 60 | 60 |
| HTTP 200 | 40 | 60 |
| HTTP 502 | 20 | 0 |
| Error rate | 33.333% | 0.000% |
| Average latency | 6.563 ms | 42.847 ms |
| p50 latency | 4.746 ms | 45.578 ms |
| p95 latency | 20.901 ms | 90.662 ms |
| p99 latency | 23.163 ms | 114.144 ms |
| Throughput | 553.940 req/s | 87.280 req/s |

## Analysis

Without the retry policy, intermittent Inventory HTTP 503 responses propagated to clients as HTTP 502 errors. Twenty of the 60 requests failed.

After applying the HTTPRoute retry policy, all 60 client requests completed successfully. The observed error rate decreased from 33.333% to 0%.

The improvement came with additional latency. Average latency increased from 6.563 ms to 42.847 ms, and p95 increased from 20.901 ms to 90.662 ms.

The shorter throughput measurement windows are not sufficient to establish a general performance limit. The results demonstrate a reliability-latency tradeoff for this test workload.

The Gateway API schema exposed the retry field, and the observed results are consistent with the retry configuration being effective.

The final Inventory request count of 269 is cumulative. Because the experiment did not capture separate before-and-after backend counts, it does not establish the exact number of retry attempts.

## Conclusion

Bounded retries eliminated client-visible failures in this 60-request experiment despite intermittent Inventory HTTP 503 responses.

Retries can improve availability during transient faults, but they introduce latency and potentially additional backend load.

A separate amplification experiment is required to measure the actual number of backend attempts.

## Evidence

- reports/03-retries.log
- manifests/ambient/20-inventory-retries.experimental.yaml
- scripts/08-run-retries.sh
- tools/experiments.py
