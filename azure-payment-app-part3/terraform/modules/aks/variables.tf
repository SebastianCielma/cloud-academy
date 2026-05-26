variable "project_name" {
  description = "Project name used in resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for AKS"
  type        = string
  default     = "1.29"
}

variable "vm_size" {
  description = "VM size for the node pool"
  type        = string
}

variable "node_count" {
  description = "Desired node count"
  type        = number
}

variable "min_count" {
  description = "Minimum node count for autoscaler"
  type        = number
}

variable "max_count" {
  description = "Maximum node count for autoscaler"
  type        = number
}

variable "aks_subnet_id" {
  description = "Subnet ID for AKS nodes"
  type        = string
}

variable "appgateway_id" {
  description = "Application Gateway ID for AGIC addon"
  type        = string
}

variable "acr_id" {
  description = "Azure Container Registry ID for pull permissions"
  type        = string
}

variable "keyvault_id" {
  description = "Key Vault ID for secrets provider"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for monitoring"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
