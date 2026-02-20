# backend.tf
terraform {
  backend "local" {
    path = "state/terraform.tfstate"
  }
}
