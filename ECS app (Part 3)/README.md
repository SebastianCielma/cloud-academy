# ECS App (Part 3)

Terraform-managed ECS Fargate application with auto-scaling, centralized logging, and CI/CD pipeline.

## Architecture

- **Networking**: VPC with public/private subnets, NAT Gateway, Internet Gateway
- **Load Balancing**: Application Load Balancer (HTTP) with health checks
- **Compute**: ECS Fargate service running a Flask container (port 8080)
- **Auto-Scaling**: Application Auto Scaling (min 1, max 3 tasks)
  - Scale out: CPU > 50% triggers a new task
  - Scale in: CPU < 25% for 5 minutes removes a task
- **Logging**: CloudWatch Log Group with 14-day retention
- **CI/CD**: GitHub Actions with OIDC authentication

## Prerequisites

- AWS account with S3 backend bucket and DynamoDB lock table
- GitHub repository with configured secrets:
  - `AWS_PLAN_ROLE_ARN` - IAM role ARN for terraform plan (read-only)
  - `AWS_APPLY_ROLE_ARN` - IAM role ARN for terraform apply (full permissions)
  - `AWS_ECR_URL` - ECR repository URL
- GitHub environment `production-approval` configured for manual approval

## Remote State

```hcl
backend "s3" {
  bucket         = "bucket-sebastian-akademia"
  key            = "ecs-app/terraform.tfstate"
  region         = "eu-north-1"
  encrypt        = true
  dynamodb_table = "terraform-lock-table"
}
```

## Pipeline Stages

The CI/CD is split into two separate workflows.

### Init and Plan (`ecs_plan.yml`) - automatic

Runs automatically on every push to `main`:

1. `terraform init`
2. `terraform fmt -check`
3. `terraform validate`
4. `tflint`
5. `terraform plan -out=tfplan`
6. Upload plan as artifact

### Apply and Docker Build (`ecs_apply.yml`) - manual

Triggered manually via GitHub Actions "Run workflow" button:

1. Download plan artifact from the latest plan run
2. Login to Amazon ECR
3. Build and push Docker image to ECR
4. `terraform init`
5. `terraform apply tfplan`

## Pipeline Authentication

The pipeline uses OIDC to assume two separate IAM roles:

| Role | Purpose | Permissions |
|------|---------|-------------|
| Plan Role | `terraform plan` | ReadOnlyAccess + S3/DynamoDB state access |
| Apply Role | `terraform apply` | AdministratorAccess |

## Viewing Logs

Access application logs in the AWS Console:

```
CloudWatch > Log groups > /ecs/part3
```

Logs are retained for 14 days and automatically deleted after that period.

## Local Deployment

```bash
terraform init
terraform plan
terraform apply
```

## Accessing the Application

After deployment, the application is available at the ALB DNS name:

```bash
terraform output alb_dns_name
```
