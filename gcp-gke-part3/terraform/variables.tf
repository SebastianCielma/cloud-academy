variable "project_id" {
  description = "The ID of the GCP project"
  type        = string
}

variable "region" {
  description = "The region for the infrastructure"
  type        = string
  default     = "europe-west1"
}

variable "tags" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {
    project = "static-website" 
  }
}