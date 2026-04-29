terraform {
  source = "../../../modules/eks"
}

include "root" {
  path = find_in_parent_folders()
}

dependency "network" {
  config_path = "../network"

  mock_outputs = {
    vpc_id          = "vpc-mock123"
    private_subnets = ["subnet-mock1", "subnet-mock2"]
  }
}

inputs = {
  environment     = "dev"
  cluster_name    = "finpay-dev-eks"
  cluster_version = "1.30"

  vpc_id     = dependency.network.outputs.vpc_id
  subnet_ids = dependency.network.outputs.private_subnets

  node_min_size       = 1
  node_max_size       = 2
  node_desired_size   = 1
  node_instance_types = ["t3.medium"]
}