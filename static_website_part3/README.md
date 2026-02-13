
# Static Website on S3 + CloudFront (Part 3)

https://d35nsyghtiz0ky.cloudfront.net/

## Prerequisites

This project uses a remote S3 backend with DynamoDB state locking. The following resources must exist in AWS before initialization:

| Resource       | Purpose        | Requirements                          |
|----------------|----------------|---------------------------------------|
| S3 Bucket      | State storage  | Versioning enabled, private ACL       |
| DynamoDB Table | State locking  | Partition key: `LockID` (type String) |

If your bucket or table names differ from the defaults in the repository, update `versions.tf`.

## Features

### HTTP to HTTPS Redirect
All HTTP requests are automatically redirected (301) to HTTPS via `viewer_protocol_policy = "redirect-to-https"` on the CloudFront default cache behavior.

### AWS WAF Rate Limiting
A WAFv2 Web ACL is attached to the CloudFront distribution with a rate-based rule limiting each source IP to 100 requests per minute (500 per 5-minute WAF evaluation window).

### Custom Error Pages
CloudFront is configured to serve a friendly HTML error page (`error.html`) for all 4xx (403, 404) and 5xx (500, 502, 503, 504) errors. The error page is stored in the S3 origin bucket.

### Real-Time Logging and Monitoring
- **Access Logs**: CloudFront standard access logs are stored in a dedicated S3 logging bucket (`<bucket-name>-logs`) with:
  - Server-side encryption (AES256)
  - Versioning enabled
  - Lifecycle rule: logs expire after 30 days
  - Full public access block enabled
- **CloudWatch Dashboard** (`StaticWebsite-Monitor-Part3`): Tracks total requests, 4xx/5xx error rates, and WAF blocked requests.
- **CloudWatch Alarms**:
  - High 5xx error rate (threshold: 5%)
  - High WAF blocked requests (threshold: 1000 per 5 minutes)
  - Both alarms send notifications via SNS topic (`static-website-alerts`)

## CI/CD Pipeline

The project uses GitHub Actions with the following stages:

| Stage | Trigger | Description |
|-------|---------|-------------|
| Init + Plan | Automatic on push to `main` | `terraform init`, `terraform fmt -check`, `terraform validate`, `tflint`, `terraform plan` |
| Apply | Manual (`workflow_dispatch`) | Downloads the plan artifact and runs `terraform apply` |

### Authentication
The pipeline assumes two AWS IAM roles via OIDC (no long-lived credentials):
- **Plan Role**: `ReadOnlyAccess` + scoped Terraform state access (S3 + DynamoDB)
- **Apply Role**: `PowerUserAccess` + limited IAM permissions for resource management

The plan output is saved as a pipeline artifact and fed into the Apply stage to prevent drift.

## Configuration

Define environment-specific values in `terraform.tfvars`:

    aws_region          = "eu-north-1"
    website_bucket_name = "your-bucket-name"

## Deployment

### 1. Initialization

    terraform init

### 2. Format and Validate

    terraform fmt -check
    terraform validate

### 3. Plan

    terraform plan

### 4. Apply

    terraform apply

## Validation

1. Open the `website_url` output in a browser to verify the site loads over HTTPS
2. Visit `http://` URL to confirm 301 redirect to HTTPS
3. Access a non-existent path to verify the custom 4xx error page is served
4. Confirm logs appear in the `<bucket-name>-logs` S3 bucket under `cf-logs/` prefix
5. Check the CloudWatch Dashboard `StaticWebsite-Monitor-Part3` for live metrics

## Project Structure

    .
    ├── main.tf                 # Root module: S3, CloudFront, bucket policy
    ├── variables.tf            # Input variables
    ├── outputs.tf              # Output values
    ├── versions.tf             # Terraform/provider versions, S3 backend
    ├── providers.tf            # AWS provider configuration
    ├── waf.tf                  # WAFv2 Web ACL with rate limiting
    ├── cloudwatch.tf           # CloudWatch Dashboard
    ├── alarms.tf               # CloudWatch Alarms + SNS topic
    ├── iam_cicd.tf             # OIDC provider + Plan/Apply IAM roles
    ├── index.html              # Website index page
    ├── error.html              # Custom error page
    └── modules/
        ├── s3/                 # S3 website bucket + logging bucket
        └── cloudfront/         # CloudFront distribution + OAC
