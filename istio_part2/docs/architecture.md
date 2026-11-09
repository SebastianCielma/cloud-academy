# Architecture

## Request Path

```text
Client
  |
  | kubectl port-forward
  v
API Gateway :8080
  |
  | GET /order
  v
Order Service :8080
  |                        Ambient L4                 Ambient L7
  | GET /payment            ztunnel                    waypoint
  +----> payment-service ---> HBONE ---> payment-waypoint ---> payment-service-v1
  |                                                         |-> payment-service-v2
  |
  | GET /inventory
  +----> inventory-service
```

The client reaches API Gateway through a local port-forward. The Order Service makes internal Kubernetes Service calls and is therefore the source of the traffic evaluated by the payment waypoint.

## Service Separation

`payment-service` is the stable name used by callers. It is labeled `istio.io/use-waypoint: payment-waypoint` and is the `parentRef` of `payment-routing` HTTPRoute. Its Kubernetes selector points to v1 as a fallback in the absence of the waypoint route.

`payment-service-v1` and `payment-service-v2` are independent Services backed by independent Deployments. The HTTPRoute points explicitly to these Services. Both versions remain ready during weighted routing and rollback.

## Ambient Enrollment

The entire `istio-part2` namespace is enrolled in Ambient Mesh with `istio.io/dataplane-mode: ambient`. A `gateway.networking.k8s.io/v1` Gateway with `gatewayClassName: istio-waypoint` provisions a service-scoped waypoint. Only `payment-service` selects that waypoint.

The ztunnel component provides the L4 mesh transport, workload identities and mTLS. The waypoint adds L7 HTTP processing, route matching and backend selection.

## Workload Identity

The five application Deployments use five ServiceAccounts: `api-gateway`, `order-service`, `inventory-service`, `payment-service-v1`, and `payment-service-v2`. Identity is associated with the ServiceAccount rather than an individual Pod IP.

## Versioning and Controlled Failure

The two Payment images are tagged `istio-part2/app:v1` and `istio-part2/app:v2`, with a version embedded in the image environment. Both are built from the same lab source. Responses contain `version` so that traffic distribution can be measured through the complete service chain.

Version v2 can return HTTP 500 for `GET /payment` when `X-Lab-V2-Regression: true` is supplied. This opt-in regression keeps the stable and failure experiments reproducible without changing the Deployment after rollout begins.

## Release Paths

| Route manifest | v1 | v2 | Purpose |
| --- | ---: | ---: | --- |
| `10-traffic-100-v1.yaml` | 100 | 0 | Initial safe route |
| `11-traffic-90-10.yaml` | 90 | 10 | Canary step 1 |
| `12-traffic-75-25.yaml` | 75 | 25 | Canary step 2 |
| `13-traffic-50-50.yaml` | 50 | 50 | Canary step 3 |
| `14-traffic-100-v2.yaml` | 0 | 100 | Full promotion |
| `15-header-based.yaml` | Default | Beta only | Release-channel routing |
| `16-traffic-100-v1-rollback.yaml` | 100 | 0 | Emergency rollback |
| `17-mirroring-optional.yaml` | Primary | Mirrored GET | Non-blocking validation |

All route manifests define the same resource, `HTTPRoute/payment-routing`. Applying one replaces the previous route specification rather than creating conflicting routes.

## Resource Constraints

Application resources are intentionally small for a local Minikube profile. The waypoint consumes additional resources beyond the five application containers. Load-testing concurrency is limited by default to avoid overwhelming a low-memory development environment.
