module "network" {
  source     = "./modules/network"
  project_id = var.project_id
  region     = var.region
  vpc_name   = "private-gke-vpc"
  tags       = var.tags
}

module "bastion" {
  source       = "./modules/bastion"
  project_id   = var.project_id
  region       = var.region
  network_name = module.network.vpc_name
  subnet_name  = module.network.system_subnet_name
  tags         = var.tags
}

module "gke" {
  source             = "./modules/gke"
  project_id         = var.project_id
  region             = var.region
  network_id         = module.network.vpc_id
  subnet_id          = module.network.workload_subnet_name
  pod_range_name     = module.network.pod_range_name
  service_range_name = module.network.service_range_name
  bastion_cidr       = "10.40.0.0/28"
  tags               = var.tags
}