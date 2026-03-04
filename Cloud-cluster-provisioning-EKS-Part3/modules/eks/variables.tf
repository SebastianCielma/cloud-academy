variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs where cluster and nodes will be deployed"
  type        = list(string)
}

variable "bastion_security_group_id" {
  description = "Security Group ID of the Bastion host to allow API access"
  type        = string
}

variable "bastion_role_arn" {
  description = "IAM Role ARN of the Bastion host to grant Kubernetes RBAC permissions"
  type        = string
}