module "docker_registry" {
  source = "./modules/gcp-registry"

  region        = var.region
  registry_id   = "payment-registry"
  sa_account_id = "cicd-publisher-sa"
}