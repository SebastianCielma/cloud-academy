variable "subnet_id" {
  description = "ID of the private subnet where Jenkins will run"
  type        = string
}

variable "security_group_id" {
  description = "Security Group ID for the EC2 instance"
  type        = string
}

variable "iam_profile_name" {
  description = "IAM Instance Profile name for Jenkins"
  type        = string
}

variable "availability_zone" {
  description = "Availability Zone for the EC2 instance and EBS volume"
  type        = string
}