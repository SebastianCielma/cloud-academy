# Statistical Analysis of Weighted Routing

## Model

For an intended v2 share `p` and `n` independently routed HTTP requests, the number of v2 responses can be approximated using a binomial random variable:

`X ~ Binomial(n, p)`

Its expected value is `n × p`, and its standard deviation is `sqrt(n × p × (1 - p))`.

For the required sample size `n = 1000`:

| Route | Expected v2 count | Standard deviation | Approximate 95% interval for v2 count |
| --- | ---: | ---: | ---: |
| 90/10 | 100 | 9.49 | 81–119 |
| 75/25 | 250 | 13.69 | 223–277 |
| 50/50 | 500 | 15.81 | 469–531 |

These intervals are approximate, not exact acceptance requirements. The test program reports observed counts and uses a four-standard-deviation diagnostic threshold to detect serious configuration problems while avoiding overly strict assumptions about random variation.

Actual observations may also be affected by nonindependent requests, traffic bursts, config convergence, timeouts, and failures. Such factors should be investigated when results are unexpectedly distant from the target.

## Measurements

The measurement tool sends every request through API Gateway and Order Service, extracts the nested Payment Service version, and records HTTP status, latency, and request identifier.

- `throughput_rps` is the count of completed client attempts divided by the elapsed wall-clock duration.
- `error_rate` is the fraction of client attempts with status outside the successful HTTP 2xx–3xx range, including connection failures.
- `p50`, `p95`, and `p99` use the nearest-rank definition over measured client request latencies.
- Version shares are based on all client attempts; unknown versions are reported and fail validation.
- Failures originating in Payment v2 retain the v2 field in the nested JSON response and remain classifiable.

The lab does not claim that every measured effect is caused solely by the mesh. Host performance, Kubernetes scheduling, proxy load, and request concurrency can influence results.

## Controlled Regression

During a 75/25 canary, when all sampled requests carry the regression header and only v2 responds with HTTP 500, the expected overall error rate is approximately 25%. After routing-only rollback to v1, the expected error rate is 0% under the same test header, assuming the stable service and other dependencies remain healthy.

The script records baseline, regression and rollback results separately. The allowed regression range in its automated check is intentionally wide, 12–40%, to guard against abnormal deviations without pretending that an exact 25% is guaranteed.
