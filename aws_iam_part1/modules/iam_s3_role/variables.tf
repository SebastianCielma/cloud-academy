variable "role_name" {
  type        = string
  description = "Name of the IAM role"
}

variable "trusted_account_ids" {
  type        = list(string)
  description = "List of AWS Account IDs allowed to assume this role"
}

variable "s3_bucket_arn" {
  type        = string
  description = "ARN of the S3 bucket to grant read access to"
}

variable "external_id" {
  type        = string
  description = "External ID required to assume the role"
}