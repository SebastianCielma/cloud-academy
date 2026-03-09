module "vpc" {
  source = "./modules/vpc"
}

module "database" {
  source          = "./modules/rds"
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  db_username     = "finpay_admin"
  db_password     = var.db_password 
}

module "eks" {
  source     = "./modules/eks"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  cluster_name = "finpay-prod"
}