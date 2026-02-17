module "networking" {
  source       = "./modules/networking"
  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
}

module "load_balancing" {
  source         = "./modules/load_balancing"
  project_name   = var.project_name
  vpc_id         = module.networking.vpc_id
  public_subnets = module.networking.public_subnets
}

module "compute" {
  source                = "./modules/compute"
  project_name          = var.project_name
  aws_region            = var.aws_region
  vpc_id                = module.networking.vpc_id
  private_subnets       = module.networking.private_subnets
  alb_security_group_id = module.load_balancing.alb_security_group_id
  target_group_arn      = module.load_balancing.target_group_arn
}