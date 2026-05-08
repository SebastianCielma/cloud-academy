variable "resource_group_name" {
  description = "The name of the resource group where the storage account will be created."
  type        = string
}

variable "location" {
  description = "The Azure region to deploy the storage account."
  type        = string
}

variable "storage_name" {
  description = "The globally unique name for the storage account."
  type        = string
}