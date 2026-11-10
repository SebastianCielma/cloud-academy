# Experiment 01: Baseline

## Requirement

Measure request latency, p95, p99, error rate, and throughput before configuring additional resilience policies.

## Objective

Evaluate normal application behavior and the effect of intermittent Inventory Service HTTP 503 responses on client-facing availability.

## Test Configuration

| Parameter | Value |
|---|---|
| Kubernetes context | kind-istio-part3 |
| Namespace | istio-part3 |
| Service mesh | Istio Ambient |
| Requests per scenario | 60 |
| Concurrency | 5 |
| Additional resilience policies | None |

## Results

| Metric | Healthy baseline | Inventory intermittent 503 |
|---|---:|---:|
| Total requests | 60 | 60 |
| Successful requests | 60 | 40 |
| Failed requests | 0 | 20 |
| HTTP 200 | 60 | 40 |
| HTTP 502 | 0 | 20 |
| Error rate | 0.00% | 33.33% |
| Mean latency | 36.432 ms | 4.469 ms |
| p95 latency | 341.792 ms | 6.091 ms |
| p99 latency | 345.710 ms | 6.324 ms |
| Throughput | 134.549 req/s | 1043.223 req/s |

## Analysis

The healthy scenario completed all 60 requests successfully.

During intermittent Inventory Service failures, 20 of 60 client requests failed. Inventory returned HTTP 503, which propagated through Order Service and resulted in HTTP 502 responses from API Gateway.

The different latency and throughput values should not be interpreted as evidence of improved performance during failures. The samples were short, and startup effects or timing variability may have influenced the measurements.

## Conclusion

Without additional retries, transient dependency failures directly affect client-facing availability.

The baseline provides a reference for evaluating the resilience mechanisms introduced in subsequent experiments.

## Original Experiment Output

The complete recorded command output follows.

~~~text
Environment
{
  "context": "kind-istio-part3",
  "mode": "ambient_without_l7_rules",
  "namespace": "istio-part3"
}

Healthy baseline
{
  "average_latency_ms": 36.432,
  "concurrency": 5,
  "elapsed_seconds": 0.446,
  "error_rate_percent": 0.0,
  "failure_count": 0,
  "http_status_counts": {
    "200": 60
  },
  "max_latency_ms": 346.127,
  "method": "GET",
  "p50_latency_ms": 6.304,
  "p95_latency_ms": 341.792,
  "p99_latency_ms": 345.71,
  "requests": 60,
  "sample_failures": [],
  "success_count": 60,
  "throughput_rps": 134.549,
  "url": "http://127.0.0.1:60967/order"
}

Inventory periodic 503 without retries
{
  "average_latency_ms": 4.469,
  "concurrency": 5,
  "elapsed_seconds": 0.058,
  "error_rate_percent": 33.333,
  "failure_count": 20,
  "http_status_counts": {
    "200": 40,
    "502": 20
  },
  "max_latency_ms": 6.423,
  "method": "GET",
  "p50_latency_ms": 4.441,
  "p95_latency_ms": 6.091,
  "p99_latency_ms": 6.324,
  "requests": 60,
  "sample_failures": [
    {
      "error": "",
      "index": 1,
      "latency_ms": 6.118,
      "response": "{\"service\":\"api-gateway\",\"order\":{\"service\":\"order-service\",\"dependency\":\"inventory\",\"downstream_status\":503}}",
      "status": 502,
      "success": false
    },
    {
      "error": "",
      "index": 5,
      "latency_ms": 4.384,
      "response": "{\"service\":\"api-gateway\",\"order\":{\"service\":\"order-service\",\"dependency\":\"inventory\",\"downstream_status\":503}}",
      "status": 502,
      "success": false
    },
    {
      "error": "",
      "index": 8,
      "latency_ms": 4.833,
      "response": "{\"service\":\"api-gateway\",\"order\":{\"service\":\"order-service\",\"dependency\":\"inventory\",\"downstream_status\":503}}",
      "status": 502,
      "success": false
    }
  ],
  "success_count": 40,
  "throughput_rps": 1043.223,
  "url": "http://127.0.0.1:60967/order"
}

Inventory counters
{
  "active_requests": 1,
  "inventory_requests": 120,
  "overload_rejections": 0,
  "payment_attempts": 0,
  "payment_conflicts": 0,
  "payments_created": 0,
  "payments_replayed": 0,
  "peak_active_requests": 2,
  "probe_attempts_for_request": 0,
  "probe_requests_received": 0,
  "requests_completed": 161,
  "requests_received": 162,
  "service": "inventory-service"
}

Execution status
{
  "status": "completed"
}


~~~
