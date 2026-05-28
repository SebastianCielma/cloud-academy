variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "environment" {
  type = string
}

variable "vnet_address_space" {
  type = list(string)
}

variable "subnet_prefixes" {
  type = object({
    public   = string
    aks      = string
    security = string
    database = string
  })
}

variable "aks_node_count" {
  type    = number
  default = 2
}

variable "aks_min_count" {
  type    = number
  default = 1
}

variable "aks_max_count" {
  type    = number
  default = 3
}

variable "aks_vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}

variable "db_admin_username" {
  type    = string
  default = "pgadmin"
}

variable "db_admin_password" {
  type      = string
  sensitive = true
}

variable "registry_name" {
  type = string
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}

# ---------------------------------------------------------
# GitHub Actions Self-Hosted Runners
# ---------------------------------------------------------

variable "github_pat" {
  description = "GitHub Personal Access Token for self-hosted runners authentication"
  type        = string
  sensitive   = true
}
