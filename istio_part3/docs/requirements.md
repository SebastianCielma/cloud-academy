# Requirement and Evidence Matrix

| Assignment requirement | Implementation | Planned evidence |
|---|---|---|
| Four-service Kubernetes baseline and health checks | `apps/server.py`, `manifests/base/` | `reports/01-baseline.*` |
| Latency, p95, p99, error rate and throughput | `tools/loadtest.py` | Benchmark JSON and CSV samples |
| Five-second Payment delay and two-second timeout | `X-Lab-Payment-Delay-Ms`, ambient `HTTPRoute` | `reports/02-timeouts.*` |
| Work continues after timeout | Payment counters and completion logs | Payment state before, immediately after and after waiting |
| Inventory periodic HTTP 503 and bounded retry | Inventory error injection, Gateway API retry if supported, sidecar retry fallback | `reports/03-retries.*` or `03-retries-sidecar.*` |
| Retry amplification in Order and mesh | Application retry option and sidecar `VirtualService` | `reports/04-retry-amplification.*` |
| Idempotent payment with lost response | SQLite transaction, idempotency key and deliberately dropped first reply | `reports/05-idempotency.*` |
| Three-second delay fault | Sidecar `VirtualService` fixed delay | `reports/06-fault-injection.*` |
| HTTP 503 fault | Sidecar `VirtualService` abort | `reports/06-fault-injection.*` |
| Percentage-based errors | Sidecar `VirtualService` abort at 25 percent | `reports/06-fault-injection.*` |
| Circuit breaking and overload | Ambient waypoint `DestinationRule`, sidecar alternative | `reports/07-overload.*` and `07-overload-sidecar.*` |
| Cascading failure before and after mitigation | Payment slowdown and ambient HTTPRoute timeout | `reports/08-cascading-failure.*` |
| Runtime feature support | CRD schema check, waypoint and HTTPRoute status | `reports/00-capabilities.*` |
| Nine additional theory questions | `docs/theory.md` | This document |

All results are generated at experiment execution time. An absent result file means the corresponding experiment has not yet been executed. HTTPRoute schema acceptance does not alone establish that the proxy implements a retry feature; compare actual backend counters and outcomes.
