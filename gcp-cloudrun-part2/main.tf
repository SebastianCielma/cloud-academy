module "networking" {
  source     = "./modules/networking"
  project_id = var.project_id
  region_1   = var.region_1
  region_2   = var.region_2
}

module "cloud_run" {
  source       = "./modules/cloud_run"
  project_id   = var.project_id
  region       = var.region_1
  image_url    = var.image_url
  connector_id = module.networking.vpc_connector_id
}