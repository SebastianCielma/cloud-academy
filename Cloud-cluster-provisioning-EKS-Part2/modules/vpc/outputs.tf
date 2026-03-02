output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "ID list for EKS subnets"
  value       = module.vpc.private_subnets
}