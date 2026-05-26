variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
}

variable "environment" {
  description = "Environment name (production, development)"
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for the Virtual Network"
  type        = list(string)
}

variable "subnet_prefixes" {
  description = "CIDR prefixes for subnets"
  type = object({
    public   = string
    aks      = string
    security = string
    database = string
  })
}

variable "aks_node_count" {
  description = "Desired number of AKS nodes"
  type        = number
  default     = 2
}

variable "aks_min_count" {
  description = "Minimum number of AKS nodes for autoscaler"
  type        = number
  default     = 1
}

variable "aks_max_count" {
  description = "Maximum number of AKS nodes for autoscaler"
  type        = number
  default     = 3
}

variable "aks_vm_size" {
  description = "VM size for AKS node pool"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "postgresql_sku" {
  description = "SKU name for PostgreSQL Flexible Server"
  type        = string
  default     = "GP_Standard_D2s_v3"
}

variable "postgresql_version" {
  description = "PostgreSQL major version"
  type        = string
  default     = "15"
}

variable "postgresql_storage_mb" {
  description = "Max storage in MB for PostgreSQL"
  type        = number
  default     = 32768
}

variable "db_admin_username" {
  description = "Administrator username for PostgreSQL"
  type        = string
  default     = "pgadmin"
}

variable "db_admin_password" {
  description = "Administrator password for PostgreSQL"
  type        = string
  sensitive   = true
}

variable "registry_name" {
  description = "Name of the Azure Container Registry (from Part 1)"
  type        = string
}

variable "log_retention_days" {
  description = "Retention period in days for Log Analytics"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
