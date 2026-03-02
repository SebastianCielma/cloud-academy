output "cluster_name" {
  description = "EKS Cluster name"
  value       = module.eks.cluster_name
}

output "configure_kubectl" {
  description = "kubectl configuration"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}