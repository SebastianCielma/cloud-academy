terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state-prod"
    storage_account_name = "sttfstateb1abe5c0"
    container_name       = "tfstate"
    key                  = "core.tfstate"
  }
}