variable "common_tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
  default = {
    project     = "static-website"
    environment = "prod"
    managed_by  = "terraform"
  }
}

variable "location" {
  description = "Global Azure region for all resources in this deployment"
  type        = string
  default     = "northeurope"
}