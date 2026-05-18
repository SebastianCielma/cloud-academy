variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "common_tags" {
  description = "Common tags for resources"
  type        = map(string)
}

variable "subnet_id" {
  description = "ID of the private subnet for the ACA Environment"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  type        = string
}

variable "acr_login_server" {
  description = "ACR login server URL"
  type        = string
}

variable "acr_username" {
  description = "ACR admin username"
  type        = string
}

variable "acr_password" {
  description = "ACR admin password"
  type        = string
  sensitive   = true
}