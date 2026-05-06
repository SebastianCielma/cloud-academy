output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for the Kubernetes API"
  value       = module.eks.cluster_endpoint
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS nodes"
  value       = module.eks.node_security_group_id
}

output "karpenter_iam_role_arn" {
  description = "IAM Role ARN for Karpenter"
  value       = module.karpenter.iam_role_arn
}

output "karpenter_queue_name" {
  description = "SQS Karpenter"
  value       = module.karpenter.queue_name
}

output "karpenter_node_iam_role_name" {
  description = "IAM role for Karpenter"
  value       = module.karpenter.node_iam_role_name
}

