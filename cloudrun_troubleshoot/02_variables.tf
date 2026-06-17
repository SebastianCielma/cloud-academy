variable "project_id" {
  description = "GCP project ID"
  type        = string
}
variable "region" {
  description = "Region (e.g., europe-west1)"
  type        = string
  default     = "europe-west1"
}
variable "name" {
  description = "Base name/prefix"
  type        = string
  default     = "troubleshoot-gcp"
}
variable "repo_name" {
  description = "Artifact Registry repo"
  type        = string
  default     = "app-images"
}
variable "web_image" {
  description = "Cloud Run image"
  type        = string
}

variable "domain" {
  description = "Optional hostname for HTTPS"
  type        = string
  default     = ""
}
# Optional VPC connector (for egress to VPC). Leave true if you need it.
variable "create_vpc_connector" {
  type    = bool
  default = false
}
variable "vpc_cidr" {
  type    = string
  default = "10.70.0.0/16"
}
variable "subnet_cidr" {
  type    = string
  default = "10.70.1.0/24"
}
variable "subnet_region" {
  type    = string
  default = "europe-west1"
}
# Autoscaling knobs
variable "min_instances" {
  type    = number
  default = 1
}
variable "max_instances" {
  type    = number
  default = 5
}
# metric: "rps" or "concurrency"
variable "autoscale_metric" {
  type    = string
  default = "rps"
}
# If metric=rps → target requests per second per instance; if concurrency → concurrent requests per instance
variable "autoscale_target" {
  type    = number
  default = 50
}
