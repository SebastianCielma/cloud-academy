# Evidence Index

All entries below are expected output paths. A file should be marked as evidence only after its corresponding experiment has executed successfully.

## Installation and Waypoint

- `reports/03-initial-v1-baseline.log`: Initial full-chain routing to v1.
- `reports/03-initial-v1-baseline.json`: Initial structured metrics.
- `reports/09-waypoint.yaml`: Programmed waypoint Gateway and status.
- `reports/09-httproute.yaml`: Applied HTTPRoute and its conditions.
- `reports/09-payment-service.yaml`: Stable Service waypoint label and fallback selector.
- `reports/09-pods.log`: Application and waypoint Pod state.

## Weighted Routing

- `reports/05-weighted-90-10.log`, `.json`, `.csv`: Target v1 90%, v2 10%, at least 1,000 attempts.
- `reports/05-weighted-75-25.log`, `.json`, `.csv`: Target v1 75%, v2 25%, at least 1,000 attempts.
- `reports/05-weighted-50-50.log`, `.json`, `.csv`: Target v1 50%, v2 50%, at least 1,000 attempts.
- `reports/05-weighted-100-v2.log`, `.json`, `.csv`: Full promotion to v2.

## Header-Based Routing

- `reports/06-header-default.log`, `.json`, `.csv`: Missing release header routes only to v1.
- `reports/06-header-beta.log`, `.json`, `.csv`: Beta release header routes only to v2.
- `reports/06-header-stable.log`, `.json`, `.csv`: Other release header routes only to v1.

## Regression and Rollback

- `reports/07-pre-regression.log`, `.json`, `.csv`: Canary before error injection.
- `reports/07-regression.log`, `.json`, `.csv`: Canary with v2 HTTP 500 regression.
- `reports/07-rollback.log`, `.json`, `.csv`: Routing-only rollback with the same regression trigger.
- `reports/07-deployments-before.log`: Both Payment Deployments before experiment.
- `reports/07-deployments-after.log`: Both Payment Deployments after experiment.
- `reports/09-payment-v1.log`: Stable Payment access records.
- `reports/09-payment-v2.log`: Candidate Payment access and regression records.

## Optional Mirroring

- `reports/08-optional-mirroring.log`, `.json`, `.csv`: Client versions and mirrored v2 counter delta.

## Application and Configuration

- `manifests/base/`: Kubernetes infrastructure and individual ServiceAccounts.
- `manifests/ambient/`: Service waypoint configuration.
- `manifests/routes/`: Traffic splits, header routing, rollback and optional mirroring.
- `apps/server.py`: Readable version and controlled HTTP 500 response.
- `tests/`: Automated application and metrics validation.

## Screenshots

Use `evidence/` for optional screenshots of the terminal and Gateway API resource status. Screenshots are supplementary to the raw reports.
