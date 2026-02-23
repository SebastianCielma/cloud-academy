# ECS Troubleshooting Task

Diagnose and remediate a broken ECS Fargate service behind an Application Load Balancer.

## Architecture

```mermaid
flowchart TB
    subgraph Internet
        U[Users]
    end

    subgraph AWS["AWS Cloud — eu-central-1"]
        subgraph VPC["VPC 10.0.0.0/16"]

            subgraph PUB["Public Subnets"]
                direction LR
                PUB_A["10.0.0.0/24<br/>eu-central-1a"]
                PUB_B["10.0.1.0/24<br/>eu-central-1b"]
            end

            IGW[Internet Gateway]
            NAT[NAT Gateway + EIP]
            ALB["Application Load Balancer<br/>HTTP :80"]
            TG["Target Group<br/>port 80 · ip target"]

            subgraph PRIV["Private Subnets"]
                direction LR
                PRIV_A["10.0.10.0/24<br/>eu-central-1a"]
                PRIV_B["10.0.11.0/24<br/>eu-central-1b"]
            end

            subgraph ECS["ECS Cluster (Fargate)"]
                SVC["Service: web<br/>desired count: 1"]
                TASK["Task Definition<br/>256 CPU · 512 MB<br/>nginx:latest"]
            end

            subgraph SCALING["Auto Scaling"]
                AST["Target: 1–6 tasks"]
                SO["Scale Out: CPU ≥ 70%"]
                SI["Scale In: CPU < 30%"]
            end

            ECR["ECR Repository"]
            CW["CloudWatch Logs + Alarms"]
        end
    end

    subgraph Security["Security Groups"]
        SG_ALB["ALB SG<br/>ingress: 80/tcp 0.0.0.0/0"]
        SG_TASK["Tasks SG<br/>ingress: 80/tcp from ALB SG"]
    end

    U -->|HTTP :80| IGW
    IGW --> ALB
    ALB --> TG
    TG --> SVC
    SVC --> TASK
    TASK -->|private subnet| NAT
    NAT -->|image pull| ECR
    TASK -->|logs| CW
    SO & SI --> AST
    AST --> SVC
    ALB -.-> SG_ALB
    TASK -.-> SG_TASK
    ALB --- PUB_A & PUB_B
    TASK --- PRIV_A & PRIV_B
    NAT --- PUB_A
```

## Issues Found & Fixed

| # | Issue | Root Cause | Fix |
|---|-------|-----------|-----|
| 1 | ALB returning 503 | Target Group port `8080`, health check `/health` | Changed to port `80`, path `/` |
| 2 | HTTP:80 "Not Reachable" | Missing Security Group ingress rules | Added ingress to ALB SG and Tasks SG |
| 3 | Tasks stuck in PENDING | Empty ECR repository + missing IAM roles | Pushed image to ECR, created IAM roles |
| 4 | No auto scaling | Missing scaling policies and CloudWatch alarms | Added step scaling policies + CPU alarms |

## Project Structure

```
├── 01_backend.tf          # Local state backend
├── 02_providers.tf        # AWS provider config
├── 03_versions.tf         # Terraform + provider versions
├── 04_variables.tf        # Input variables
├── 05_outputs.tf          # Outputs
├── 06_networking.tf       # VPC, subnets, IGW, NAT, route tables
├── 07_ecr.tf              # ECR repository + lifecycle policy
├── 08_iam.tf              # Task execution + task IAM roles
├── 09_logs.tf             # CloudWatch log group
├── 10_security_groups.tf  # ALB + ECS tasks security groups
├── 11_alb.tf              # ALB, listener, target group
├── 12_ecs.tf              # Cluster, task def, service, scaling
├── 13_autoscaling.tf      # Auto scaling target
├── Dockerfile             # nginx:alpine + curl
├── RUNBOOK.md             # Incident runbook
└── CHANGELOG.md           # Change log with evidence
```

## Usage

```bash
terraform init
terraform plan
terraform apply
```

## Documentation

- [RUNBOOK.md](RUNBOOK.md) — Root cause analysis and remediation steps
- [CHANGELOG.md](CHANGELOG.md) — Change log with evidence
