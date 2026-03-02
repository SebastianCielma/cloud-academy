variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "eks-minimal"
}

variable "common_tags" {
  description = "Project tags"
  type        = map(string)
  default = {
    project = "static-website"
  }
}