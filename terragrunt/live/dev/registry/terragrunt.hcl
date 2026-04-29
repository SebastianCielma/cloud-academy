terraform {
  source = "../../../modules/registry"
}

include "root" {
  path = find_in_parent_folders()
}

inputs = {
  environment = "dev"
  
  # Lista repozytoriów, które chcemy utworzyć dla naszych mikroserwisów
  repository_names = [
    "payment-api",
    "payment-worker"
  ]
}