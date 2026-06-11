variable "bucket_name" {
  type        = string
  description = "Name of the main website GCS bucket."
}

variable "region" {
  type        = string
  description = "Location for the GCS buckets."
}

variable "tags" {
  type        = map(string)
  description = "Labels to apply to the buckets."
  default     = {}
}

variable "index_html_path" { type = string }
variable "error_html_path" { type = string }
variable "html_4xx_path" { type = string }
variable "html_5xx_path" { type = string }

variable "log_bucket_name" {
  type        = string
  description = "Name of the bucket storing LB access logs."
}

variable "project_id" {
  type        = string
  description = "The GCP Project ID required for the logging sink."
}