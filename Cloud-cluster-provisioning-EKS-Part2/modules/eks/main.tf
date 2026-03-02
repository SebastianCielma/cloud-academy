module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.4"  

  cluster_name    = "${var.project_name}-cluster"
  cluster_version = "1.30"

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnets

  cluster_endpoint_public_access = true 

  eks_managed_node_groups = {
    minimal_node_group = {
      min_size     = 1
      max_size     = 1
      desired_size = 1

      instance_types = ["t3.small"]
    }
  }

  tags = var.common_tags
}