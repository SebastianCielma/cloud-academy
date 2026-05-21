variable "prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "jumpbox_subnet_id" { type = string }
variable "bastion_subnet_id" { type = string }
variable "admin_password" {
  type      = string
  sensitive = true
}