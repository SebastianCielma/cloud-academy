module "vpc" {
  source = "./modules/vpc"
  vpc_name        = var.vpc_name
  vpc_cidr        = var.vpc_cidr
  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  tags = {
    Environment = var.environment
    Project     = "finpay"
  }
}

module "database" {
  source = "./modules/rds"

  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  vpc_cidr_block  = var.vpc_cidr
  private_subnets = module.vpc.private_subnets
  backend_sg_id = module.eks.node_security_group_id
  
  db_username     = "postgres"
  db_password     = var.db_password
  
}

module "kubernetes" {
  source = "./modules/eks"

  cluster_name    = "finpay-${var.environment}-cluster"
  environment     = var.environment
  
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets
}