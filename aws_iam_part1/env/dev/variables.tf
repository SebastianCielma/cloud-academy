variable "app_role_name" {
  type        = string
  description = "Name of the IAM role for the application"
}

variable "allowed_account_ids" {
  type        = list(string)
  description = "List of AWS Account IDs allowed to assume the role"
}

variable "target_bucket_arn" {
  type        = string
  description = "ARN of the S3 bucket"
}

variable "aws_region" {
  type        = string
  default = "eu-central-1"
  description = "AWS region"
}

variable "partner_external_id" {
  type        = string
  description = "External ID for partner access"
}