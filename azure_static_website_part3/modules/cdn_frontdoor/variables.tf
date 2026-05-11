variable "resource_group_name" {
  description = "The name of the resource group."
  type        = string
}

variable "profile_name" {
  description = "The name of the Azure Front Door profile."
  type        = string
}

variable "origin_host_name" {
  description = "The host name of the origin (e.g., the storage account static website endpoint)."
  type        = string
}

variable "tags" {
  description = "A map of tags to apply to the resource."
  type        = map(string)
}