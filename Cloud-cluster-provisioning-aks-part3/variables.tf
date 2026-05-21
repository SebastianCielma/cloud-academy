variable "location" {
  description = "Region"
  type        = string
  default     = "eastus"
}

variable "project_tags" {
  description = "project tags"
  type        = map(string)
  default     = {}
}

variable "admin_password" {
  description = "Bastion password"
  type        = string
  sensitive   = true
}