variable "vpc_id" {
  description = "The ID of the VPC where the bastion will be deployed"
  type        = string
}

variable "private_subnet_id" {
  description = "The ID of the private subnet where the bastion instance will be placed"
  type        = string
}