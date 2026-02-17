# ECS App (Part 2)

Terraform infrastructure for a "Hello World" Python application on ECS Fargate.

## Repository Structure

```
.
├── main.tf              # Root module - composes all child modules
├── variables.tf         # Input variable declarations
├── outputs.tf           # Root outputs (ALB DNS, ECR URL)
├── providers.tf         # AWS provider with default tags
├── versions.tf          # Terraform and provider versions, S3 backend
├── terraform.tfvars     # Variable overrides
└── modules/
    ├── networking/       # VPC, subnets, IGW, NAT GW, route tables
    ├── load_balancing/   # ALB, target group, listener, security group
    └── compute/          # ECR, ECS cluster, task definition, service, auto-scaling
```

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI configured with appropriate credentials
- S3 bucket and DynamoDB table for remote state (already provisioned)
- Docker image pushed to ECR repository

## Usage

Initialize Terraform:

```bash
terraform init
```

Preview changes:

```bash
terraform plan
```

Apply infrastructure:

```bash
terraform apply
```

Clean up all resources:

```bash
terraform destroy
```

## Outputs

- `alb_dns_name` - DNS name of the Application Load Balancer
- `ecr_repository_url` - URL of the ECR repository
