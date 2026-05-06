variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the EC2 instance will be deployed"
  type        = string
}

variable "subnet_id" {
  description = "Private Subnet ID"
  type        = string
}

variable "eks_node_sg_id" {
  description = "Security Group ID of the EKS nodes to allow database access"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block to allow internal traffic"
  type        = string
}

variable "db_password" {
  description = "Password for the PostgreSQL database"
  type        = string
  sensitive   = true
}
