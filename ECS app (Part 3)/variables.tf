variable "aws_region" {
  description = "AWS region for resource deployment"
  type        = string
  default     = "eu-north-1"
}


variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}
