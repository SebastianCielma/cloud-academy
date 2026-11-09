# Assignment Requirements

This mapping covers the supplied Istio Part 2 assignment. It describes implemented files and planned verification, not completed Kubernetes experiments.

| Requirement | Implementation | Verification |
| --- | --- | --- |
| Local Kubernetes and Ambient Mesh | `manifests/base/00-namespace.yaml`, `scripts/00-check-environment.sh` | Namespace and Istio component status |
| Separate ServiceAccounts | `manifests/base/01-serviceaccounts.yaml`, deployments | Pod ServiceAccount assignment |
| Four logical services and health checks | `apps/server.py`, `manifests/base/02-deployments.yaml`, `03-services.yaml` | Full-chain response and probes |
| Waypoint deployed and attached | `manifests/ambient/00-payment-waypoint.yaml`, Service label | Gateway Programmed, HTTPRoute Accepted, v2 routing through stable Service |
| Two Payment versions with version identity | `apps/Dockerfile`, versioned Deployments | Application response contains `version` |
| Weighted 90/10, minimum 1,000 requests | `11-traffic-90-10.yaml`, `05-run-weighted.sh` | Observed percentages and CSV data |
| Weighted 75/25, minimum 1,000 requests | `12-traffic-75-25.yaml`, `05-run-weighted.sh` | Observed percentages and CSV data |
| Weighted 50/50, minimum 1,000 requests | `13-traffic-50-50.yaml`, `05-run-weighted.sh` | Observed percentages and CSV data |
| Full rollout 100% v2 | `14-traffic-100-v2.yaml` | All sampled payment responses show v2 |
| Header routing beta to v2 | `15-header-based.yaml`, `06-run-header.sh` | Beta only to v2, others to v1 |
| Routing match priority | Header rule followed by unconditional fallback | Negative and positive header tests |
| Intentional HTTP 500 regression in v2 | `apps/server.py`, `07-run-rollback.sh` | Error-rate comparison under regression header |
| Immediate rollback without deleting v2 | `16-traffic-100-v1-rollback.yaml` | Deployment snapshots and zero errors |
| Optional mirroring | `17-mirroring-optional.yaml`, `08-run-mirroring-optional.sh` | v2 process-local counters and v1 client responses |
| Answer eight additional questions | `docs/theory.md` | Written answers |
| Preserve manifests and evidence | `manifests/`, `reports/`, `evidence/` | Git repository and experiment artifacts |

## Experimental Acceptance

Weighted tests must use at least 1,000 valid requests per configuration. Failure to observe the expected routing proportion should be investigated before the experiment is marked complete.

An accepted HTTPRoute and a programmed Gateway are configuration checks. Successful routing of requests to v2 through the stable Service provides an additional data-plane check, because the stable Service selects v1 as its fallback.

The rollback is considered successful only if the regression-triggering header remains present during the final measurement and all observed successful payment responses originate from v1 while both Payment Deployments remain available.

Optional mirroring is not a required passing criterion for the assignment. It should be reported as supported and verified, unsupported, or inconclusive based on actual cluster results.
