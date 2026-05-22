resource "azurerm_container_registry" "this" {
  name                = var.registry_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku

  admin_enabled = false

  tags = var.tags
}

resource "azurerm_user_assigned_identity" "cicd_pusher" {
  name                = "id-${var.registry_name}-pusher"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "acr_push" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.cicd_pusher.principal_id
  #
}