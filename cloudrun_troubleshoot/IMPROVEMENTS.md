# Infrastructure Improvements — Cloud Run Troubleshooting

## Changes Applied

### 1. Cloud Run Autoscaling (07_cloudrun.tf)

**What**: Added `autoscaling.knative.dev/minScale` and `autoscaling.knative.dev/maxScale` annotations to the Cloud Run template metadata.

**Where**: `google_cloud_run_service.web.template.metadata.annotations`

**Why**: Without these annotations, Cloud Run defaults to `min=0` and `max=100`. The service could scale to zero during idle periods (cold start latency) or over-provision to 100 instances (cost explosion). Setting `min=1` keeps a warm instance for low-latency responses. Setting `max=5` caps costs while allowing burst capacity.

**Evidence**: Cloud Run docs state: _"If minScale is 0, Cloud Run scales to zero when there are no requests"_. Users reported cold-start latency and cost issues.

---

### 2. Container Port Declaration (07_cloudrun.tf)

**What**: Added explicit `ports { container_port = 8080 }` to the container spec.

**Where**: `google_cloud_run_service.web.template.spec.containers.ports`

**Why**: While Cloud Run defaults to port 8080, explicit declaration ensures the health check probe and traffic routing target the correct port. The Dockerfile and nginx config both listen on 8080 — making this explicit prevents misconfiguration during image changes.

---

### 3. Request Timeout (07_cloudrun.tf)

**What**: Added `timeout_seconds = 300` to the Cloud Run spec.

**Where**: `google_cloud_run_service.web.template.spec.timeout_seconds`

**Why**: Default timeout is 300s but relying on defaults is fragile. Explicit timeout documentation prevents silent behavior changes during API version upgrades. During traffic spikes, long-running requests need adequate time before being terminated.

---

### 4. VPC Connector — Conditional Dependency Fix (07_cloudrun.tf, 04_network.tf)

**What**: Removed hard `depends_on` for `google_vpc_access_connector.connector` and made it conditional via annotations. Added the missing `google_vpc_access_connector` resource to `04_network.tf`.

**Where**: `07_cloudrun.tf` depends_on block + template annotations; `04_network.tf` new resource.

**Why**: The original code had `depends_on = [google_vpc_access_connector.connector]` but the connector resource did not exist in any file — `terraform plan` would fail immediately. The connector is now properly defined and conditionally attached based on `var.create_vpc_connector`.

---

### 5. Artifact Registry IAM — Compute Engine Default SA (06_iam.tf)

**What**: Added `roles/artifactregistry.reader` for the default Compute Engine service account (`{project_number}-compute@developer.gserviceaccount.com`).

**Where**: `google_project_iam_member.ar_reader_compute`

**Why**: Cloud Run uses the Compute Engine default service account to pull container images at the infrastructure level, regardless of the runtime service account configured on the service. Without this permission, new instance starts fail with image pull errors. The custom SA already had the role, but that only applies to application-level access to AR.

**Evidence**: GCP documentation: _"Cloud Run uses the Compute Engine default service account to pull images"_.

---

### 6. Unauthenticated Public Access (07_cloudrun.tf)

**What**: Added `google_cloud_run_service_iam_member` granting `roles/run.invoker` to `allUsers`.

**Where**: `google_cloud_run_service_iam_member.public_access`

**Why**: Without this IAM binding, the Load Balancer receives 403 Forbidden when forwarding requests to Cloud Run. The service is public-facing by design (behind an External HTTP(S) LB), so unauthenticated invocation is required.

---

### 7. Serverless NEG (08_loadbalancer.tf)

**What**: Added `google_compute_region_network_endpoint_group` of type `SERVERLESS` pointing to the Cloud Run service.

**Where**: `google_compute_region_network_endpoint_group.serverless_neg`

**Why**: The Load Balancer had no backend to forward traffic to. A Serverless NEG is the required integration point between External HTTP(S) LB and Cloud Run.

---

### 8. Backend Service (08_loadbalancer.tf)

**What**: Added `google_compute_backend_service` with `EXTERNAL_MANAGED` scheme, referencing the Serverless NEG, with logging enabled.

**Where**: `google_compute_backend_service.default`

**Why**: The URL map needs a backend service to route to. Using `EXTERNAL_MANAGED` enables the newer global external Application Load Balancer with advanced traffic management. Logging at 100% sample rate enables debugging LB health and request distribution.

---

### 9. URL Map (08_loadbalancer.tf)

**What**: Added `google_compute_url_map` with the backend service as default.

**Where**: `google_compute_url_map.url_map`

**Why**: The HTTP and HTTPS proxies referenced `google_compute_url_map.url_map.id` but the resource did not exist. All traffic routes to the single Cloud Run backend.

---

### 10. Forwarding Rules (08_loadbalancer.tf)

**What**: Added `google_compute_global_forwarding_rule` for HTTP (port 80) and conditional HTTPS (port 443).

**Where**: `google_compute_global_forwarding_rule.http` and `google_compute_global_forwarding_rule.https`

**Why**: Without forwarding rules, the global IP address has nothing listening on it. HTTP is always enabled; HTTPS is conditional on providing a domain for the managed SSL certificate.

---

### 11. Outputs (10_outputs.tf)

**What**: Added outputs for Cloud Run URL, LB IP address, and service account email.

**Where**: New file `10_outputs.tf`

**Why**: Operators need the LB IP for DNS configuration and the Cloud Run URL for direct access/debugging.

---

## Recommendations for Future Improvements

### Cost Optimization

| Recommendation | Impact | Effort |
|---|---|---|
| Set `min_instances = 0` for non-production environments | Eliminates idle cost in dev/staging | Low |
| Use `cpu_idle = true` (CPU throttled when no requests) for non-latency-sensitive workloads | Reduces per-instance cost by ~75% | Low |
| Add budget alerts via `google_billing_budget` | Prevents cost surprises | Medium |
| Use committed use discounts for stable baseline load | 20-50% savings | Low |

### Automation

| Recommendation | Impact | Effort |
|---|---|---|
| Add Cloud Build trigger for CI/CD pipeline | Automates build + deploy on push | Medium |
| Use `terraform_remote_state` with GCS backend | Team collaboration, state locking | Low |
| Add HTTP-to-HTTPS redirect via URL map | Security best practice | Low |
| Implement blue/green deployments via traffic splitting | Zero-downtime releases | Medium |

### Monitoring & Observability

| Recommendation | Impact | Effort |
|---|---|---|
| Add `google_monitoring_alert_policy` for error rate > 1% | Early incident detection | Medium |
| Add uptime checks via `google_monitoring_uptime_check_config` | Availability SLI | Low |
| Configure structured logging with log-based metrics | Actionable dashboards | Medium |
| Add Cloud Trace for latency analysis | p95/p99 visibility | Low |

### Security & Maintenance

| Recommendation | Impact | Effort |
|---|---|---|
| Enable Cloud Armor WAF on the backend service | DDoS/OWASP protection | Medium |
| Add Vulnerability Scanning on the AR repository | CVE detection in images | Low |
| Implement Binary Authorization | Supply chain security | High |
| Rotate service account keys via Workload Identity | Eliminates key management | Medium |
