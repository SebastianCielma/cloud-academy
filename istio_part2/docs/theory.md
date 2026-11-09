# Theory: Additional Questions

## 1. How does a canary deployment differ from a rolling update?

A rolling update replaces old Pods with new Pods progressively according to Deployment strategy settings. Its main purpose is to maintain availability during replacement. Traffic distribution normally follows the currently ready endpoints and is not a precise canary percentage.

A canary deployment runs the stable and candidate versions in parallel and intentionally directs a controlled subset of traffic to the candidate. The operator uses measured results to decide whether to increase the candidate's share, keep it unchanged, or roll back. This experiment keeps two independent Payment Deployments and uses HTTPRoute weights to control their shares.

## 2. Why do two Deployments not guarantee a 90/10 traffic split?

A Kubernetes Deployment controls replica count, not the per-request percentage assigned by a Gateway API HTTPRoute. Even with nine stable Pods and one candidate Pod, endpoint selection, persistence of connections, retries, and load-balancer behavior may prevent an exact 90/10 request distribution.

A route with explicit backend weights provides the intended L7 split. The ratio is probabilistic in finite samples rather than exactly guaranteed.

## 3. What is HTTPRoute and what is the role of a waypoint proxy?

HTTPRoute is a resource from Kubernetes Gateway API that describes HTTP request matching and routing rules, including headers, path matches, backends and backend weights.

In this project it attaches to the stable `payment-service` via `parentRefs` with `kind: Service`. The Istio waypoint implements the L7 HTTP routing decision. Ztunnel itself handles L4 transport and does not inspect HTTP headers or select weighted backends per HTTP request.

## 4. Must 100 requests produce exactly a 90/10 distribution?

No. Each request has an intended 10% chance of reaching the candidate version, so 100 independent requests produce a binomial distribution with an expected count of 10 and a standard deviation of approximately 3. Observing 7 or 13 candidate requests is ordinary sampling variation.

For 1,000 requests with a 10% candidate weight, the expected count is 100 and the standard deviation is approximately 9.49. The larger sample provides a more stable estimate of the intended routing ratio.

## 5. When should header-based routing be used?

Header-based routing is useful for internal beta testing, staged feature access, A/B experiments, specific test cohorts and controlled debugging. A request bearing `x-release-channel: beta` can reach v2 regardless of the current default version.

The client-supplied release header is not an authentication mechanism. Production systems must not treat an untrusted header as proof of authorization or user identity.

## 6. Why can a routing rollback be faster than a Deployment rollback?

Changing an HTTPRoute updates proxy configuration without requiring a new container image, terminating the candidate Pods, or waiting for a replacement Deployment to become ready. Routing can return to a healthy stable version while the candidate remains deployed for diagnosis.

Actual convergence depends on control-plane propagation and data-plane health. A routing rollback is therefore fast in principle but should be verified with real traffic rather than assumed instantaneous.

## 7. What are the risks of traffic mirroring?

Mirroring sends additional copies of requests to a second backend while ignoring the mirrored responses. This increases backend traffic and resource consumption. Mirroring state-changing operations such as payment creation may duplicate charges, inventory reservations, messages, or other irreversible side effects.

Mirroring should be restricted to read-only operations or backed by strong safeguards such as request isolation, sandboxed dependencies and idempotency. This project's optional example only mirrors the read-only `GET /payment` lab endpoint.

## 8. How does L4 load balancing differ from L7 routing?

L4 load balancing uses connection-level properties such as IP addresses, ports and transport connections. It does not inherently know the HTTP method, URL path, or application request headers.

L7 routing understands application protocol messages such as HTTP requests and can select different backend services per request based on headers, paths or configured request weights. Istio Ambient separates these responsibilities: ztunnel supplies the L4 mesh, while an optional waypoint enables L7 routing.
