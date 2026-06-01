variable "resource_group_name" {
  type        = string
  description = "resource group name"
}

variable "location" {
  type        = string
  description = "Location"
}

variable "aks_oidc_issuer_url" {
  type        = string
  description = "OIDC Issuer AKS cluster"
}