variable "security_group_id" {
  description = "Security Group ID for the Zabbix Agent"
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM Instance Profile for SSM access"
  type        = string
}

variable "zabbix_server_ip" {
  description = "Private IP of the Zabbix Server for agent configuration"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where the instance will be launched"
  type        = string
}

variable "agent_hostname" {
  description = "Hostname of the Zabbix Agent"
  type        = string
}