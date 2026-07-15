# TerraOps Part 1 Starter

## Reverse Engineering & Debugging

This is the initial student snapshot. TerraOps has recently been handed over to the Platform
Engineering team, and the staging deployment is now unstable after infrastructure and deployment
changes.

Your job is to understand how the platform works, identify the real root cause and restore the
staging deployment without rewriting the whole system.

## What You Should Investigate

Start from the existing code, configuration, generated files and logs. Build a map of how TerraOps
deploys the Academy Control API on a VM:

- CLI command flow,
- environment configuration loading,
- Terraform variable generation,
- AWS or Azure network and VM stacks,
- VM bootstrap,
- systemd service runtime,
- Nginx reverse proxy,
- API readiness checks,
- SQLite initialization.

## Expected Symptoms

The incident is intentionally misleading. Infrastructure may appear healthy while the application is
not actually ready.

Use these symptoms as signals, not conclusions:

- provisioning appears to complete,
- the VM and reverse proxy may be present,
- `/health` can respond,
- `/ready` and `/stats` can fail,
- Nginx 502s can appear as a secondary symptom,
- application logs point toward database/runtime problems.

## Useful Commands

AWS:

```bash
python -m terraops.main validate --cloud aws --env staging
python -m terraops.main deploy --cloud aws --env staging --stack network
python -m terraops.main deploy --cloud aws --env staging --stack vm
python -m terraops.main status --cloud aws --env staging
```

Azure:

```bash
python -m terraops.main validate --cloud azure --env staging
python -m terraops.main deploy --cloud azure --env staging --stack network
python -m terraops.main deploy --cloud azure --env staging --stack vm
python -m terraops.main status --cloud azure --env staging
```

Provider-specific Terraform code is split under `stacks/aws` and `stacks/azure`. The generated
tfvars are also mapped through provider-specific modules in `terraops/terraform`.

Part 1 focuses on VM-based deployment: `network` first, then `vm`. Serverless and notifications
commands are part of the broader TerraOps interface, but they are not the primary path for this
incident.

## Deliverable

Provide a minimal, durable fix and document:

- how TerraOps works,
- what caused the staging failure,
- how you diagnosed it,
- what changed,
- how you verified `/health`, `/ready` and `/stats`.
