# Progressive Deployment Guard Lab — Student Version

This package provides the lab environment for the **Bash – Progressive Deployment Guard** task.

## Important

The deployment guard script is **not included** in this package.

Your task is to implement:

```bash
deploy-guard.sh
```

based on the assignment requirements.

## Included files

- `app_v1.py` — healthy application version `v1`
- `app_v2.py` — version `v2`, can be healthy or broken
- `start_service.sh` — starts selected version locally on port 8080
- `stop_service.sh` — stops the local service
- `service_status.sh` — shows process, health and deployment state
- `reset_lab.sh` — restores the lab to a clean `v1` state
- `state/` — deployment state files for 3 simulated instances

## Requirements

- Linux, WSL, or macOS with Bash
- Python 3
- curl

## Quick start

```bash
chmod +x *.sh app_v1.py app_v2.py
bash reset_lab.sh
bash service_status.sh
```

Healthy response should be available at:

```bash
curl http://localhost:8080/health
```

Expected:

```json
{"status":"UP","version":"v1"}
```

## What you need to implement

Create a script named:

```bash
deploy-guard.sh
```

Your script should:
- perform progressive rollout
- validate health after each step
- stop rollout on failure
- roll back to previous version if needed
- return meaningful exit codes

## Suggested validation scenarios

### 1. Successful rollout
Your script should deploy `v2` successfully.

### 2. Failed rollout with rollback
Simulate a broken version by starting version `v2` with:

```bash
BROKEN_V2=true bash start_service.sh v2
```

Or design your script to treat a target like `v2-broken` as a failed rollout case.

## Suggested student flow

1. Reset the environment:
   ```bash
   bash reset_lab.sh
   ```
2. Inspect current state:
   ```bash
   bash service_status.sh
   ```
3. Implement `deploy-guard.sh`
4. Test successful rollout to `v2`
5. Reset the environment
6. Test failed rollout and rollback
7. Verify final state

## Cleanup

```bash
bash stop_service.sh
rm -f service.pid service.log
```
