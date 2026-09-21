variable "security_group_id" {
  description = "Security Group ID for the Zabbix Server"
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM Instance Profile for SSM access"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where the instance will be launched"
  type        = string
}