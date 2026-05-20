resource "azurerm_resource_group" "aks_rg" {
  name     = "rg-aks-terraform-devops"
  location = var.location
  tags     = var.project_tags
}

module "aks_cluster" {
  source              = "./modules/aks"
  cluster_name        = "aks-minimal-tf"
  resource_group_name = azurerm_resource_group.aks_rg.name
  location            = azurerm_resource_group.aks_rg.location
  tags                = var.project_tags
}