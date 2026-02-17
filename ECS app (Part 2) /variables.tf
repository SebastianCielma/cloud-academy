variable "aws_region" {
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  type        = string
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
}

variable "environment" {
  type        = string
  default     = "dev"
}