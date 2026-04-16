variable "vpc_cidr" {
  description = "CIDR block for the Jenkins VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet (ALB)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet (EC2 Jenkins)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "Availability zone for the subnets"
  type        = string
}

variable "vpc_cidr" { default = "10.0.0.0/16" }
variable "public_subnet_cidr_a" { default = "10.0.1.0/24" }
variable "public_subnet_cidr_b" { default = "10.0.2.0/24" }
variable "private_subnet_cidr" { default = "10.0.3.0/24" }
variable "az_a" { type = string }
variable "az_b" { type = string }