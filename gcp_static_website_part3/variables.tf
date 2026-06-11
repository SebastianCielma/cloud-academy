variable "project_id" {
  type        = string
  description = "The ID of the GCP project."
}

variable "region" {
  type        = string
  default     = "europe-west1"
  description = "The default GCP region for resources."
}

variable "bucket_name" {
  type        = string
  description = "The globally unique name for the GCS bucket."
}

variable "log_bucket_name" {
  type        = string
  description = "Name of the bucket storing LB access logs."
}

variable "alert_email" {
  type        = string
  description = "Email address to send Cloud Monitoring alerts."
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to apply to the resources."
  default = {
    project = "static-website"
  }
}