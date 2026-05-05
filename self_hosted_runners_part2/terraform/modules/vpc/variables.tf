variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC (e.g., 10.0.0.0/16)"
  type        = string
}

variable "azs" {
  description = "List of Availability Zones"
  type        = list(string)
}

variable "private_subnets" {
  description = "List of CIDR blocks for private subnets (used for EKS and RDS)"
  type        = list(string)
}

variable "public_subnets" {
  description = "List of CIDR blocks for public subnets (used for Load Balancers and NAT)"
  type        = list(string)
}

variable "tags" {
  description = "Global tags to be applied to all resources"
  type        = map(string)
  default     = {}
}