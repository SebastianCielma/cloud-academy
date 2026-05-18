resource "azurerm_resource_group" "main" {
  name     = "rg-helloapp-prod"
  location = var.location
  tags     = var.common_tags
}

module "networking" {
  source              = "./modules/networking"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  common_tags         = var.common_tags
}

module "log_analytics" {
  source              = "./modules/log_analytics"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  common_tags         = var.common_tags
}

module "acr" {
  source              = "./modules/acr"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  common_tags         = var.common_tags
}

module "aca" {
  source              = "./modules/aca"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  common_tags         = var.common_tags

  subnet_id = module.networking.private_subnet_1_id

  log_analytics_workspace_id = module.log_analytics.workspace_id

  acr_login_server = module.acr.login_server
  acr_username     = module.acr.admin_username
  acr_password     = module.acr.admin_password
}

module "appgw" {
  source              = "./modules/appgw"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  common_tags         = var.common_tags

  vnet_id   = module.networking.vnet_id
  subnet_id = module.networking.public_subnet_1_id

  aca_fqdn = module.aca.app_fqdn

  log_analytics_workspace_id = module.log_analytics.workspace_id
}