resource "azurerm_resource_group" "rg" {
  name     = "rg-aks-private-task"
  location = "eastus"
  tags     = var.project_tags
}

module "network" {
  source              = "./modules/network"
  prefix              = "devops"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.project_tags
}

module "aks" {
  source               = "./modules/aks"
  prefix               = "devops"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  aks_system_subnet_id = module.network.aks_system_subnet_id
  tags                 = var.project_tags
}

module "bastion" {
  source              = "./modules/bastion"
  prefix              = "devops"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  jumpbox_subnet_id   = module.network.jumpbox_subnet_id
  bastion_subnet_id   = module.network.bastion_subnet_id

  admin_password = var.admin_password
}