module "vpc" {
  source = "./modules/vpc"

  vpc_name        = var.vpc_name
  vpc_cidr        = var.vpc_cidr
  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
}

module "bastion" {
  source = "./modules/bastion"

  vpc_id            = module.vpc.vpc_id
  private_subnet_id = module.vpc.private_subnets[0]
}

module "eks" {
  source = "./modules/eks"

  cluster_name       = var.cluster_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets

  bastion_security_group_id = module.bastion.bastion_security_group_id
  bastion_role_arn          = module.bastion.bastion_role_arn
}