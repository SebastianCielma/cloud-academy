######################
# IDENTITY
######################
# User-assigned Managed Identity for Container Apps
resource "azurerm_user_assigned_identity" "uami" {
  name                = "${var.name}-uami"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Grant AcrPull role to the managed identity on the ACR
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.uami.principal_id
}
