output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "bastion_role_arn" {
  description = "The IAM Role ARN attached to the Bastion host"
  value       = module.bastion.bastion_role_arn
}