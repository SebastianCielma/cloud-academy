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

variable "vnet_id" {
  description = "Virtual Network ID for DNS zone link"
  type        = string
}

variable "security_subnet_id" {
  description = "Subnet ID for private endpoint"
  type        = string
}

variable "db_password" {
  description = "Database password to store in Key Vault"
  type        = string
  sensitive   = true
}

variable "db_connection_string" {
  description = "Database JDBC connection string to store in Key Vault"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
