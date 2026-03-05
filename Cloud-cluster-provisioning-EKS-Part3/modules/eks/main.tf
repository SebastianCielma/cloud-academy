module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.30"

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = false

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  cluster_security_group_additional_rules = {
    ingress_bastion = {
      description              = "Allow Bastion host to communicate with the cluster API"
      protocol                 = "tcp"
      from_port                = 443
      to_port                  = 443
      type                     = "ingress"
      source_security_group_id = var.bastion_security_group_id
    }
  }

  eks_managed_node_groups = {
    minimal_nodes = {
      min_size       = 1
      max_size       = 2
      desired_size   = 1
      instance_types = ["t3.medium"]
    }
  }

  enable_cluster_creator_admin_permissions = true

  access_entries = {
    bastion = {
      principal_arn = var.bastion_role_arn
      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
}