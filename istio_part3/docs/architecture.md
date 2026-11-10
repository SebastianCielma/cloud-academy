# System Architecture

```text
Client
  |
  v
API Gateway
  |
  v
Order Service
  |                 \
  v                  v
Payment Service    Inventory Service
```

The four workloads run in the `istio-part3` namespace, each with a dedicated Kubernetes ServiceAccount, Deployment, Service, readiness probe and liveness probe. A single Python HTTP implementation is parameterized with `SERVICE_NAME` and packaged in one image.

The primary deployment runs in ambient mode. Ztunnel secures workload communication at Layer 4, while a service-level waypoint handles supported HTTPRoute policies. Backend requests reach the payment or inventory Kubernetes Service through the waypoint only when that Service is explicitly enrolled.

A separate `istio-part3-sidecar` namespace contains Order, Payment and Inventory services with injected Envoy sidecars. This deployment isolates stable Istio VirtualService retry and fault-injection demonstrations from Gateway API's ambient feature limitations. Only three workloads are needed for these experiments; the fourth, API Gateway, remains part of the primary ambient deployment.

## Endpoints

| Service | Endpoint | Purpose |
|---|---|---|
| API Gateway | `GET /order` | Full synchronous workflow |
| API Gateway | `GET /order/payment-only` | Payment dependency benchmark |
| API Gateway | `POST /checkout` | Payment workflow with an optional idempotency key |
| Order Service | `GET /order` | Payment probe followed by inventory |
| Order Service | `GET /order/payment-only` | Payment probe with bounded application retries |
| Order Service | `POST /checkout` | Forward payment with bounded application retries |
| Payment Service | `GET /payment/probe` | Delay, transient 503, and attempt-count scenarios |
| Payment Service | `POST /payment` | Atomic idempotent payment recording |
| Payment Service | `GET /stats` | Request, overload, and payment execution counters |
| Inventory Service | `GET /inventory` | Periodic HTTP 503 scenario |
| Inventory Service | `GET /stats` | Request counters |
| All workloads | `GET /healthz`, `GET /readyz` | Kubernetes probes |

`X-Request-ID` is forwarded between services to correlate retry attempts. Experimental failure controls use `X-Lab-*` request headers and must not be exposed as production APIs.

The SQLite payment database is stored on an `emptyDir` volume. It is transactionally safe for concurrent requests in a single Pod, but it is not a production payment ledger, not shared between replicas, and not durable across Pod recreation. Production idempotency requires persistent shared storage and stronger controls around expiration and key reuse.

Local benchmark traffic is driven through Kubernetes port forwarding. The portion of traffic between the application workloads still traverses the service mesh, but ingress and local host overhead are not representative of production traffic. Tests must be performed under comparable load conditions and interpreted together with backend counters.
