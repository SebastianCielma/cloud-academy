variable "vpc_id" {
  description = "ID of the Jenkins VPC"
  type        = string
}

variable "allowed_ips" {
  description = "List of allowed CIDR blocks for Jenkins UI access"
  type        = list(string)
}