variable "project_id" { type = string }
variable "region" { type = string }
variable "network_id" { type = string }
variable "subnet_id" { type = string }
variable "pod_range_name" { type = string }
variable "service_range_name" { type = string }
variable "bastion_cidr" { type = string }
variable "tags" { type = map(string) }