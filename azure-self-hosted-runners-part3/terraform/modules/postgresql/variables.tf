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

variable "database_subnet_id" {
  description = "Subnet ID delegated to PostgreSQL"
  type        = string
}

variable "postgresql_version" {
  description = "PostgreSQL major version"
  type        = string
  default     = "15"
}

variable "sku_name" {
  description = "SKU name for the Flexible Server"
  type        = string
}

variable "storage_mb" {
  description = "Storage in MB"
  type        = number
}

variable "admin_username" {
  description = "Administrator login"
  type        = string
}

variable "admin_password" {
  description = "Administrator password"
  type        = string
  sensitive   = true
}

variable "database_name" {
  description = "Name of the application database"
  type        = string
  default     = "paymentdb"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
