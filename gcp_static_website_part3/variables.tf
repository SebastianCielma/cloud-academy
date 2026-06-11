variable "project_id" {
  type        = string
  description = "The ID of the GCP project."
}

variable "region" {
  type        = string
  description = "The default GCP region for resources."
  default     = "europe-west1"
}

variable "bucket_name" {
  type        = string
  description = "The globally unique name for the GCS bucket."
}

variable "tags" {
  type        = map(string)
  description = "A map of tags (labels in GCP) to apply to the resources."
  default = {
    project = "static-website"
  }
}
variable "project_id" { type = string }
variable "region" { type = string, default = "europe-west1" }
variable "bucket_name" { type = string }
variable "log_bucket_name" { type = string }
variable "alert_email" { type = string }
variable "tags" {
  type    = map(string)
  default = { project = "static-website" }
}