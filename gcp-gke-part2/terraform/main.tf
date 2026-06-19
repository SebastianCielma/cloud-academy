provider "google" {
  project = var.project_id
  region  = var.region
}

module "gke_minimal" {
  source       = "./modules/gke"
  project_id   = var.project_id
  region       = var.region
  cluster_name = "gke-tf-test"
  tags         = var.common_tags
}