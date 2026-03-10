variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block of the VPC to allow inbound traffic"
  type        = string
}

variable "private_subnets" {
  description = "List of private subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "paymentdb"
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
}

variable "db_password" {
  description = "Master password for the database"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name"
  type        = string
}