# Istio Part 4 — Zero Trust and Troubleshooting

This repository will contain the eight required experiments and their real terminal evidence.

## Initial deployment

Prerequisites: kind cluster `istio-part4`, Istio Ambient and Gateway API.

```bash
export ISTIO_PART4_CONTEXT=kind-istio-part4
bash scripts/01-deploy.sh
bash scripts/02-check-baseline.sh
```

## Reporting principle

Each experiment records the actual configuration, commands, observed HTTP status, and interpretation. Reports are not synthesized from expected results.

## Development status

Initial application and waypoint are included. Authorization, JWT, egress, observability, incident simulation, and final review are developed and verified in subsequent stages. No test results are claimed before execution.
