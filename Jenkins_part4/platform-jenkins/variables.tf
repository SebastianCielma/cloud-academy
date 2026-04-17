variable "aws_region" {
  description = "AWS region to deploy the infrastructure"
  type        = string
  default     = "eu-central-1"
}

variable "my_ip" {
  description = "Your public IP address for secure access (format: x.x.x.x/32)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the Jenkins controller"
  type        = string
  default     = "t3.medium" 
}