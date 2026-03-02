variable "project_name" {
  description = "Project name"
  type        = string
}

variable "vpc_id" {
  description = "VPC cluster ID"
  type        = string
}

variable "private_subnets" {
  description = "Private subnets for worker nodes"
  type        = list(string)
}

variable "common_tags" {
  description = "Project tags"
  type        = map(string)
}