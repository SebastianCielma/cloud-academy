variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "region_1" {
  description = "First region for subnets and Cloud Run"
  type        = string
  default     = "europe-west4"
}

variable "region_2" {
  description = "Second region for the secondary subnet"
  type        = string
  default     = "europe-west1"
}

variable "image_url" {
  description = "Docker image URL in Artifact Registry"
  type        = string
}

variable "default_tags" {
  description = "Default labels attached to all resources"
  type        = map(string)
  default = {
    project = "static-website"
  }
}