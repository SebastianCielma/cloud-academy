variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "aws_profile" {
  description = "Optional AWS CLI profile"
  type        = string
}

##################
# NETWORKING
##################
variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR"
  default     = "10.0.0.0/16"
}

variable "azs" {
  type        = list(string)
  description = "Two Availability Zones"
  default     = ["eu-central-1a", "eu-central-1b"]
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Two public subnet CIDRs (one per AZ)"
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Two private subnet CIDRs (one per AZ)"
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

####################
#
####################
variable "name" {
  type        = string
  description = "Prefix for resource names"
  default     = "troubleshoot-ecs"
}

variable "container_port" {
  type        = number
  description = "App container port"
  default     = 80
}

variable "alb_health_check_path" {
  type        = string
  description = "ALB Target Group health check path"
  default     = "/"
}

variable "web_desired_count" {
  type        = number
  description = "Initial desired count for web service"
  default     = 1
}

variable "web_min_capacity" {
  type        = number
  description = "Autoscaling min capacity for web service"
  default     = 1
}

variable "web_max_capacity" {
  type        = number
  description = "Autoscaling max capacity for web service"
  default     = 6
}

variable "cpu_target_percent" {
  type        = number
  description = "Target tracking CPU utilization %"
  default     = 60
}

