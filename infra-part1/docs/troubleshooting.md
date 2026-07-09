# Troubleshooting & Incident Response Guide

When the TerraOps platform or deployed workloads fail, operators should consult this guide to quickly diagnose and resolve common incidents.

## 1. Deployment Failures
**Symptom**: `CommandExecutionError` during `terraops deploy`.
* **Root Cause**: Often a misconfiguration in `variables.tf` or a failure within the underlying `terraform apply` step.
* **Action**: Review the structured logs provided by the `Command Runner`. The exact exit code and raw Terraform output are bundled directly within the error message. Ensure the target Cloud stack (`stacks/<cloud>/<type>`) exists.

## 2. Readiness & Runtime Failures
**Symptom**: `GET /ready` returns HTTP 503 on the Academy Control API.
* **Root Cause**: The application container is running, but the internal readiness probe failed (typically a database connection failure).
* **Action**: Check the SQLite database file path and permissions in the target environment. Ensure the environment variables match the expected `configs/<cloud>.<env>.yaml` configuration.

## 3. Notification & Event Failures
**Symptom**: A status changes in the API, but `terraops notifications read` returns an empty array.
* **Root Cause**: The event was either not published, rejected by the Event System, or lost in the queue.
* **Action**: 
  1. Check the API logs (Search for the `Publishing event:` string emitted by the `academy-api` logger).
  2. Verify the cloud provider's event routing rules (e.g., EventBridge).
  3. Confirm the CLI is querying the correct `--env` scope.

## 4. Configuration & Safety Blocks
**Symptom**: The CLI immediately throws a `ValueError` or `SystemExit(1)` without running any commands.
* **Root Cause**: A safety guardrail was triggered (e.g., missing YAML sections or attempting to destroy production).
* **Action**: If attempting to destroy `prod`, append `--confirm-prod-destroy`. If missing configuration sections, validate the corresponding YAML file against the required schema (`runtime`, `database`, `network`, `application`).