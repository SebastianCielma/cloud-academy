variable "aws_region" {
  type        = string
  description = "AWS region used for the VM deployment."
  default     = "eu-central-1"
}

variable "cloud" {
  type = string
}

variable "environment" {
  type = string
}

variable "database_url" {
  type = string
}

variable "app_port" {
  type    = number
  default = 8000
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}
