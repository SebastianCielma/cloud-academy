module "vpc" {
  source       = "./modules/vpc"
  project_id   = var.project_id
  region       = var.region
  network_name = "payment-vpc-prod"
  subnet_name  = "payment-subnet-prod"
}

module "cloudsql" {
  source     = "./modules/cloudsql"
  project_id = var.project_id
  region     = var.region
  network_id = module.vpc.network_id
}

module "gke" {
  source      = "./modules/gke"
  project_id  = var.project_id
  region      = var.region
  network_id  = module.vpc.network_id
  subnet_name = module.vpc.subnet_name
}