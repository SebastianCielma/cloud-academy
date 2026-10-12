variable "role_name" {
  type        = string
  description = "Name of the IAM role to be created (Account B)"
}

variable "trusted_role_arn" {
  type        = string
  description = "ARN of the role in Account A that is allowed to assume this role"
}

variable "allowed_s3_bucket_arn" {
  type        = string
  description = "ARN of the S3 bucket this role can access"
}