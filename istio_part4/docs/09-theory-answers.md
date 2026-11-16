# Istio Part 4 — Theory Questions and Answers

## 1. What is the difference between mTLS and AuthorizationPolicy?

Mutual TLS establishes an encrypted communication channel and authenticates the participating workloads using cryptographic identities. `AuthorizationPolicy` decides whether a verified workload may perform a specific action against a destination. mTLS answers *who is communicating and how is the channel protected?* AuthorizationPolicy answers *is this communication permitted?* Both mechanisms are necessary for least-privilege service communication.

## 2. Why does mTLS alone not enforce least privilege?

mTLS can validate that Inventory and Order have legitimate identities without implying that both should access Payment. Without an authorization rule, an authenticated but unauthorized workload may still invoke a sensitive service. In the baseline test, Order, Inventory and Unknown Client all obtained HTTP 200 from Payment. After policy enforcement, only Order remained authorized.

## 3. What is the difference between L4 and L7 authorization?

L4 authorization uses connection-oriented attributes such as source workload identity and port. In Ambient, ztunnel provides this enforcement, and denials can appear as connection resets or upstream 503 responses. L7 authorization works with HTTP concepts: method, path, JWT claims and request principal. A waypoint can distinguish `GET /health` from `POST /health` and return HTTP 403 for the disallowed operation even when both originate from the same workload.

## 4. Why is a waypoint needed for HTTP authorization in Ambient mode?

ztunnel operates at Layer 4 and does not evaluate the HTTP method, URL path or JWT claims. An Envoy waypoint processes L7 traffic and can enforce Service-attached `AuthorizationPolicy` and `RequestAuthentication`. The Payment waypoint allowed Order to use `GET /health` and `POST /payments` while rejecting an unauthorized method or path. The destination L4 policy had to allow the waypoint identity so that authorized L7 requests could reach the backend.

## 5. What can cause HTTP 403 and HTTP 503?

HTTP 403 often indicates a policy rejection at the HTTP layer. The measured Inventory and Unknown Client calls returned `403 RBAC: access denied`, with Envoy logging `rbac_access_denied_matched_policy[none]`. HTTP 503 commonly indicates an unavailable upstream, missing endpoints or a connection failure. The empty diagnostic Service returned `503 no healthy upstream`. An L4 policy rejection can also cause the calling proxy to surface a 503, but it may instead produce a transport error. The response code alone is not enough: inspect Envoy response details, endpoints, ztunnel and routing configuration.

## 6. How does Kubernetes NetworkPolicy complement Istio?

NetworkPolicy controls which pod/network connections are permitted at the network layer, provided that the CNI plugin enforces it. Istio supplies workload identity, mTLS, L7 authorization and application-aware routing. Together they can restrict both network paths and permitted requests. In this experiment kindnet was installed and no NetworkPolicy was present. The egress test verified one registered host through an Istio waypoint, not a global inability to bypass that waypoint; network-layer enforcement must be demonstrated separately.

## 7. How do JWT user identity and Kubernetes ServiceAccount identity differ?

A Kubernetes ServiceAccount identifies a workload running in the cluster. Istio can represent that identity through a SPIFFE principal and use it in source-based authorization. A JWT normally carries end-user or caller claims such as issuer, audience, subject, role and expiration, and must be validated using a trusted signing key. A request to `GET /payments/{id}` required **both** the `order-service` workload principal and a valid JWT carrying `role=payment-reader`. A valid JWT from an unauthorized workload would not satisfy that ServiceAccount condition.

## 8. How can application errors be distinguished from mesh errors?

Correlate the client response with waypoint access logs, ztunnel logs, application logs, Service endpoint health and route/policy status. `403 RBAC: access denied` accompanied by an Envoy RBAC detail indicates mesh authorization rejection. `503 no healthy upstream` with an empty EndpointSlice points to backend availability. A connection reset after removing a waypoint label, combined with a ztunnel policy-rejection log, points to L4 enforcement or path configuration. An application-generated error can look similar at the HTTP level, so inspect whether the request reached the upstream and whether the app recorded it.

## 9. What are the risks of an overly broad ALLOW policy?

A broad policy may grant unexpected workloads access to sensitive methods and data. A second permissive ALLOW policy can also defeat a narrower ALLOW rule, because a request may satisfy either policy. The lab therefore updated the existing waypoint ALLOW policy instead of adding an unrestricted second one. Least privilege requires explicit sources, methods, paths and, where appropriate, validated JWT claims, followed by negative tests for unauthorized cases.

## 10. Does a service mesh replace application security?

No. A mesh helps enforce transport security, workload identity, traffic policy, request authentication and observability, but applications must still validate inputs, enforce domain-specific permissions, protect data, prevent replay or double processing, manage secrets, handle business errors and maintain security updates. In this experiment Istio checked the Order ServiceAccount and JWT role, while Payment still needed to implement safe payment creation and retrieval. A secure design combines mesh controls with application-layer defenses.

## Notes on experimental evidence

The answers above use observed Part 4 outcomes where applicable. The environment was a local Istio 1.31.4 Ambient installation on kind. NetworkPolicy enforcement, multi-node resilience, production performance and comprehensive distributed tracing were not demonstrated. The three production-incident fault types were introduced in controlled stages rather than simultaneously.
