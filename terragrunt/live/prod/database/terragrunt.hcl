terraform {
  source = "../../../modules/database"
}

include "root" {
  path = find_in_parent_folders()
}

dependency "network" {
  config_path = "../network"
  mock_outputs = {
    vpc_id          = "vpc-mock123"
    private_subnets = ["subnet-mock1"]
    vpc_cidr_block  = "10.1.0.0/16"
  }
}

dependency "eks" {
  config_path = "../eks"
  mock_outputs = {
    node_security_group_id = "sg-mock123"
  }
}

inputs = {
  environment   = "prod"
  
  instance_type = "t3.large" 
  
  vpc_id         = dependency.network.outputs.vpc_id
  subnet_id      = dependency.network.outputs.private_subnets[0]
  vpc_cidr       = dependency.network.outputs.vpc_cidr_block
  eks_node_sg_id = dependency.eks.outputs.node_security_group_id
}