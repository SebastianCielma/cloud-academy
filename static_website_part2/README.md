
This project uses a remote S3 backend with DynamoDB state locking. The following resources must exist in AWS before initialization:

| Resource       | Purpose        | Requirements                          |
|----------------|----------------|---------------------------------------|
| S3 Bucket      | State storage  | Versioning enabled, private ACL       |
| DynamoDB Table | State locking  | Partition key: `LockID` (type String) |

If your bucket or table names differ from the defaults in the repository, update `versions.tf`.

## Configuration

Define environment-specific values in `terraform.tfvars`. 

## Deployment

### 1. Initialization

Download provider plugins and configure the S3 backend:

terraform init

### 2. Format and Validate

Ensure code adheres to canonical format and syntax is valid:

terraform fmt -check
terraform validate

### 3. Plan

Generate an execution plan showing resources to be created, modified, or destroyed. Always review the plan before applying:

terraform plan

### 4. Apply

terraform apply

## Validation

Upon successful application, Terraform will output the CloudFront domain name.


1. Open the `website_url` in a web browser to verify the site is loading correctly.
2. Attempt to access the S3 bucket object URL directly to verify that access is denied (`403 Forbidden`), confirming the Origin Access Control security policy is active.

## Project Structure

```
├── terraform.tfvars
└── modules/
├── s3/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
└── cloudfront/
    ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── main.tf
├── variables.tf
├── outputs.tf
└── versions.tf
```
