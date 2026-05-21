variable "prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "aks_system_subnet_id" {
  description = "Subnet id"
  type        = string
}
variable "tags" { type = map(string) }