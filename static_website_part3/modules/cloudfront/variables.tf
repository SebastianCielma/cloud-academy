variable "origin_domain_name" {
  description = "Domain name of the S3 bucket"
  type        = string
}

variable "origin_id" {
  description = "ID of the S3 origin"
  type        = string
}

variable "tags" {
  description = "Tags for the resources"
  type        = map(string)
  default     = {}
}

variable "waf_arn" {
  description = "ARN of the WAF Web ACL"
  type        = string
}

variable "logs_bucket_domain_name" {
  description = "Domain name of the logging bucket"
  type        = string
}