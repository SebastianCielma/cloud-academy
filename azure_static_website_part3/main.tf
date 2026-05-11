resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.project_name}-app"
  location = var.location
  tags     = var.tags
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

module "storage" {
  source              = "./modules/storage"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  storage_name        = "st${var.project_name}${random_string.suffix.result}"
  tags                = var.tags
}

module "cdn_frontdoor" {
  source              = "./modules/cdn_frontdoor"
  resource_group_name = azurerm_resource_group.rg.name
  profile_name        = "fd-${var.project_name}-${random_string.suffix.result}"
  origin_host_name    = module.storage.web_endpoint_host
  tags                = var.tags
}
#