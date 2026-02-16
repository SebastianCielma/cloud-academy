# variables.tf
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "aws_profile" {
  description = "Optional AWS CLI profile"
  type        = string
}

variable "owner" {
  description = "Person who creates the resources in AWS"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.100.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.100.10.0/24"
}

variable "az" {
  description = "Availability Zone for the public subnet"
  type        = string
  default     = "eu-central-1a"
}

variable "project_name" {
  description = "Tag value for Project/Name"
  type        = string
  default     = "cloudforge"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}
