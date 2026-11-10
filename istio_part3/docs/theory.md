# Additional Questions

## 1. How does a timeout differ from a retry?

A timeout limits how long a caller is willing to wait for an operation. A retry sends another attempt after a failure that may be transient. A timeout bounds waiting, while a retry can improve successful completion at the cost of extra work. They must be coordinated using an overall request deadline, limited retry attempts and backoff.

## 2. When can retries make an incident worse?

Retries can amplify traffic toward an already overloaded dependency. Concurrent callers may retry simultaneously, increasing queue lengths, connection pressure, latency and failure rates. Nested retries in multiple layers multiply the number of actual backend attempts. Unbounded retries, short delays and non-idempotent operations increase risk.

## 3. Why is idempotency necessary for payment operations?

A client may lose a successful payment response and retry an operation without knowing whether the payment was committed. An idempotency key makes repeated requests with the same semantic payload return the recorded outcome rather than charging again. Reusing a key with a different payload must be rejected. The key-to-outcome mapping must be atomic and stored durably in a production system.

## 4. What is retry amplification?

Retry amplification occurs when multiple independent retry layers multiply attempts. If a client makes three application attempts and a proxy performs three backend attempts for each, the payment backend can receive up to nine requests for one logical operation. Request counters recorded at the backend provide stronger evidence than only counting client responses.

## 5. How does circuit breaking differ from rate limiting?

Circuit breaking restricts connections, pending requests, concurrent requests, or use of unhealthy upstream endpoints to protect service availability. Rate limiting controls how many requests are admitted within a time window or against a quota. Both can reject traffic, but they respond to different overload signals and enforce different resource constraints.

## 6. What is a cascading failure?

A cascading failure occurs when a failing or slow dependency consumes resources in callers, which then become slow or unavailable to their own clients. A slow Payment Service can occupy Order Service worker threads and increase API Gateway latency. Deadlines, careful retries, concurrency limits and bulkheads can reduce the propagation of failure.

## 7. Why is a very short timeout not always optimal?

A timeout must reflect realistic latency distributions and the operation's value. A timeout below normal or high-percentile latency causes unnecessary failures and can produce additional work when combined with retries. It should be selected using baseline measurements, an end-to-end latency budget and explicit operational objectives.

## 8. How do distributed traces help diagnose retries?

Distributed tracing links client, gateway, service and proxy spans through trace context. Child spans or proxy telemetry can reveal repeated attempts, their durations, which hop failed and where time was spent. In this lab, `X-Request-ID` correlates application logs and backend attempt counters. This is not a substitute for an installed distributed tracing collector and span exporter.

## 9. Which features require a waypoint proxy in ambient mode?

Ztunnel primarily processes Layer 4 traffic and supports secure transport and workload identity. HTTP-level timeouts, retries, fault-related Layer 7 traffic management, HTTP telemetry and most HTTP policy features require a waypoint proxy. A Gateway API `HTTPRoute` is preferred for supported, stable ambient Layer 7 features. The `VirtualService` API has Alpha status for ambient and must not be mixed with `HTTPRoute` for the same workload. The separate sidecar test environment uses standard Istio `VirtualService` policies to exercise fault injection and reliable mesh retry behavior.
