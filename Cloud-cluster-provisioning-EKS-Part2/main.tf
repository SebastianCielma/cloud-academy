provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source       = "./modules/vpc"
  
  project_name = var.project_name
  vpc_cidr     = "10.0.0.0/16"
  common_tags  = var.common_tags
}

module "eks" {
  source          = "./modules/eks"
  
  project_name    = var.project_name
  vpc_id          = module.vpc.vpc_id             
  private_subnets = module.vpc.private_subnets    
  common_tags     = var.common_tags
}