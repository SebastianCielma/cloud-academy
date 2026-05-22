resource "azurerm_resource_group" "payment" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

module "private_registry" {
  source = "./modules/acr"

  registry_name       = var.registry_name
  resource_group_name = azurerm_resource_group.payment.name
  location            = azurerm_resource_group.payment.location
  sku                 = "Premium"
  tags                = var.tags
}