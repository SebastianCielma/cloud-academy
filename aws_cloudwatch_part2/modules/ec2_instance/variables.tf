variable "ami_id" {
  description = "ID for AMI"
  type        = string  
}

variable "instance_type" {
  description = "EC2 Instance Type"
  type        = string
  default     = "t3.micro"
}

variable "iam_instance_profile" {
  description = "IAM instance profile name"
  type        = string
}

variable "instance_name" { type = string }
variable "env" { type = string }
variable "app" { type = string }
variable "role" { type = string }
variable "auto_alert" { type = string }