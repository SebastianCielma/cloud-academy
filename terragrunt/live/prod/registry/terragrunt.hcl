terraform {
  source = "../../../modules/registry"
}

include "root" {
  path = find_in_parent_folders()
}

inputs = {
  environment = "prod"
  repository_names = [
    "payment-api",
    "payment-worker"
  ]
}