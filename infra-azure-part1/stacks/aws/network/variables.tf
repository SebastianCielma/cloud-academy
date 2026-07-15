variable "aws_region" {
  type        = string
  description = "AWS region used for the network deployment."
  default     = "eu-central-1"
}

variable "cloud" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.42.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.42.1.0/24"
}

variable "allowed_http_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

variable "allowed_ssh_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

