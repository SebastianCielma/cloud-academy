# ECS Troubleshooting — Runbook

## Incident Description

A public-facing application running on Amazon ECS (Fargate) behind an Application Load Balancer (ALB) was unreachable from the internet. Infrastructure-as-Code deployment (Terraform) was failing with resource conflicts, and container tasks were stuck in **PENDING** state.

The following Root Cause Analysis (RCA) documents the issues identified and the remediation steps applied.

---

## Problem 1: Terraform Deployment Error ("ResourceInUse") and ALB 503

### Root Cause

The Target Group was configured with an incorrect port (`8080` instead of `80`) and the Health Check was targeting a non-existent path (`/health`). Attempting to update the port via Terraform caused a `ResourceInUse` conflict — the Load Balancer blocked deletion of the in-use Target Group.

### Resolution (Terraform)

1. Changed the `port` attribute from `8080` to `80` and the Health Check `path` from `/health` to `/`.
2. Replaced the static `name` with `name_prefix` in the `aws_lb_target_group` resource.
3. Added a `lifecycle { create_before_destroy = true }` block, forcing AWS to perform a seamless, zero-downtime resource replacement.

### Evidence

- `terraform plan` output confirmed the Target Group would be replaced (create-before-destroy).
- After `terraform apply`, ALB returned HTTP 200 instead of 503.

---

## Problem 2: No Network Access ("Not Reachable" / Connection Timeout)

### Root Cause

Both Security Groups (ALB and ECS Tasks) were missing **Ingress rules**. All inbound traffic from the internet was rejected at the Load Balancer level, and ECS tasks could not receive forwarded traffic from the ALB.

### Resolution (Terraform)

- **ALB Security Group**: Added an Ingress rule allowing TCP traffic on port `80` from any IP address (`0.0.0.0/0`).
- **ECS Tasks Security Group**: Added an Ingress rule on port `80` accepting traffic exclusively from the ALB Security Group ID (enforcing the **Least Privilege** principle).

### Evidence

- Before fix: `curl <ALB_DNS>` → `Connection timed out`.
- After fix: `curl <ALB_DNS>` → HTTP 200 with nginx welcome page.

---

## Problem 3: Tasks Stuck in PENDING ("CannotPullContainerError")

### Root Cause

ECS containers could not start because the target Amazon ECR repository (`troubleshoot-ecs-app`) was completely **empty**. The absence of a container image prevented task initialization.

### Resolution (AWS CLI / Docker)

1. Authenticated the local Docker client with AWS ECR:
   ```bash
   aws ecr get-login-password --region eu-central-1 | \
     docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com
   ```
2. Pulled a lightweight base image:
   ```bash
   docker pull nginx:latest
   ```
3. Tagged the image with the private ECR repository address and pushed it:
   ```bash
   docker tag nginx:latest <ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com/troubleshoot-ecs-app:latest
   docker push <ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com/troubleshoot-ecs-app:latest
   ```

After populating the registry, the ECS cluster automatically pulled the image, launched tasks, and registered them as **Healthy** in the Target Group.

### Evidence

- ECS Service Events: tasks transitioned from `PENDING` → `RUNNING`.
- ALB Target Group: targets registered as `healthy`.

---

## Problem 4: Auto Scaling Not Functioning (Scale-Out / Scale-In)

### Root Cause

The Auto Scaling policies and CloudWatch alarms were **missing entirely**. The `aws_appautoscaling_target` was defined, but no scaling policies or metric alarms existed to trigger scale-out or scale-in actions.

### Resolution (Terraform)

- Added **Scale-Out** policy (`StepScaling`, +1 task) triggered by `cpu_high` alarm (CPU ≥ 70%, 1×60s evaluation).
- Added **Scale-In** policy (`StepScaling`, -1 task) triggered by `cpu_low` alarm (CPU < 30%, 3×60s evaluation).
- Configured appropriate cooldown periods (60s scale-out, 300s scale-in).

### Evidence

- CloudWatch Alarms visible in console with correct dimensions (`ClusterName`, `ServiceName`).
- Load test with ApacheBench confirmed scale-out behavior under load.

---

## Problem 5: Missing IAM Roles

### Root Cause

The `08_iam.tf` file was **empty** — no Task Execution Role or Task Role existed. Without the Task Execution Role, ECS could not authenticate to ECR to pull images or push logs to CloudWatch.

### Resolution (Terraform)

- Created `ecs_task_execution_role` with `ecs-tasks.amazonaws.com` trust policy.
- Attached the AWS managed policy `AmazonECSTaskExecutionRolePolicy` (provides ECR pull + CloudWatch Logs permissions).
- Created `ecs_task_role` for runtime task permissions.

### Evidence

- Tasks successfully pulling images from ECR after role creation.
- CloudWatch Log streams populated with container logs.

---

## Verification

- ALB endpoint (DNS) correctly loads the application welcome page on port 80.
- Successful load test performed with **ApacheBench** (`ab`), validating proper network and compute layer behavior.
- All ECS tasks in `RUNNING` state with `healthy` Target Group status.
