terraform {
  source = "../../../modules/network"
}

include "root" {
  path = find_in_parent_folders()
}

inputs = {
  vpc_name = "finpay-dev-vpc"
  vpc_cidr = "10.0.0.0/16"
  
  azs             = ["eu-central-1a", "eu-central-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  single_nat_gateway = true

  tags = {
    Environment = "dev"
  }
}