######################
# ACR
######################
resource "azurerm_container_registry" "acr" {
  name                = "${replace(var.name, "-", "")}acr"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku                 = "Standard"
  admin_enabled       = false
}
