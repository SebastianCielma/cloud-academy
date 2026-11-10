# Istio Part 3: Resilience Engineering

A reproducible Kubernetes and Istio laboratory for request timeouts, bounded retries, retry amplification, payment idempotency, fault injection, circuit breaking, overload and cascading failure.

## Compatibility

- Intended for the existing Minikube `istio-part1` profile, Kubernetes 1.34 and Istio 1.31.3 with ambient components installed.
- Uses a new `istio-part3` namespace so the original Part 1 workloads and security policies remain intact.
- Requires the Gateway API CRDs for waypoint and HTTPRoute configuration.
- Does not install Istio itself or modify the existing Istio control plane.
- Uses the `istio-part3-sidecar` namespace for dedicated sidecar experiments.
- All source code, manifests and script contents are in English.

## Architecture

Client -> API Gateway -> Order Service -> Payment Service and Inventory Service.

Read `docs/architecture.md` for the service endpoints, traffic paths, measurements, identity design and laboratory limitations.

## Project Layout

- `apps/server.py`: four HTTP services, request controls, retry logic, counters, SQLite idempotency.
- `apps/Dockerfile`: shared non-root runtime image.
- `manifests/base/`: reusable ServiceAccounts, Deployments and Services.
- `manifests/ambient/`: isolated namespace, waypoint, timeout and retry HTTPRoutes, and circuit breaker.
- `manifests/sidecar/`: isolated sidecar workload configuration and VirtualService policies.
- `tools/loadtest.py`: concurrent HTTP benchmark reporting latency distribution, throughput and errors.
- `tools/experiments.py`: experiment orchestration, cleanup and automated reporting.
- `scripts/`: explicit setup and scenario entry points.
- `reports/`: generated logs, structured JSON and per-request CSV files.
- `evidence/`: optional screenshots.
- `docs/requirements.md`: assignment evidence mapping.
- `docs/theory.md`: answers to the nine additional questions.
- `tests/`: application regression tests.

## Local Validation

```bash
python3 -m unittest discover -s tests -v
python3 -m compileall -q apps tools tests
for script in scripts/*.sh; do bash -n "$script"; done
```

## Environment Setup

```bash
./scripts/00-install-gateway-api.sh
./scripts/01-check-environment.sh
./scripts/02-build-image.sh
./scripts/03-deploy-ambient.sh
./scripts/05-check-capabilities.sh
```

The Gateway API installation script installs pinned `v1.4.1` experimental CRDs only if the Gateway API Gateway CRD is absent. It does not overwrite an existing Gateway API installation. HTTPRoute retry fields are experimental in that version, and feature availability is checked at runtime.

## Ambient Experiments

```bash
./scripts/06-run-baseline.sh
./scripts/07-run-timeouts.sh
./scripts/08-run-retries.sh
./scripts/11-run-idempotency.sh
./scripts/13-run-overload.sh
./scripts/15-run-cascading-failure.sh
```

The inventory retry test applies an experimental Gateway API HTTPRoute only when its installed schema contains `retry`. If the feature is absent or the route is rejected, the result explicitly records the reason and directs the operator to the sidecar equivalent.

## Sidecar Experiments

```bash
./scripts/04-deploy-sidecar.sh
./scripts/09-run-sidecar-retries.sh
./scripts/10-run-retry-amplification.sh
./scripts/12-run-fault-injection.sh
./scripts/14-run-sidecar-overload.sh
```

Before running sidecar experiments on a small machine, pause the Part 3 ambient deployments using `./scripts/17-pause-ambient.sh` and resume them afterward using `./scripts/18-resume-ambient.sh`. These commands never touch Part 1 workloads. The sidecar setup validates that each of its three application Pods contains an injected `istio-proxy` container.

## Evidence Collection

```bash
./scripts/16-collect-evidence.sh
```

Each experiment writes a human-readable `.log`, a JSON event record and one CSV file per benchmark run. The reported fields include request count, status distribution, throughput in requests per second, error rate, average latency, p50, p95, p99 and maximum latency. Payment counters are used to observe the number of actual backend attempts.

Results are deliberately not bundled before the experiments run; no measurements are fabricated. Read `docs/requirements.md` to map every assignment requirement to its corresponding implementation and generated evidence.

## Scope and Limitations

Timeouts cannot undo side effects or cancel a backend worker that has already started. Retries can multiply load and must be bounded. A successful HTTPRoute schema check does not prove runtime retry support. VirtualService support in ambient mode is Alpha, so the project does not mix VirtualService with HTTPRoute on ambient services. Dedicated sidecars are used for mesh fault injection and a stable retry fallback. DestinationRule policies are evaluated on a waypoint and can also be compared against an isolated sidecar variant.

The application-level lab headers, direct port forwarding, non-persistent SQLite volume, and small single-node cluster are for controlled demonstrations, not production deployment.

## Cleanup

```bash
./scripts/99-cleanup.sh
```

Cleanup deletes only the two Istio Part 3 namespaces. It does not remove the Istio installation, Part 1 applications or original Git repository content.
