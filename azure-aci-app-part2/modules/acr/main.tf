resource "azurerm_container_registry" "acr" {
  name                = "crhelloappprod${random_string.suffix.result}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true
  tags                = var.common_tags
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}