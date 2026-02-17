variable "project_name" {}
variable "vpc_id" {}
variable "private_subnets" { type = list(string) }
variable "alb_security_group_id" {}
variable "target_group_arn" {}
variable "aws_region" {}