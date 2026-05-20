variable "location" {
  description = "AKS cluster Region"
  type        = string
  default     = "eastus"
}

variable "project_tags" {
  description = "project tags"
  type        = map(string)
  default     = {}
}