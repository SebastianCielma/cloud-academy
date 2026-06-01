resource "azurerm_storage_account" "preview_sa" {
  name                     = "stfinpayprevseb123"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "preview_artifacts" {
  name                  = "preview-artifacts"
  storage_account_name  = azurerm_storage_account.preview_sa.name
  container_access_type = "private"
}

resource "azurerm_user_assigned_identity" "preview_identity" {
  name                = "mi-finpay-preview-envs"
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_role_assignment" "preview_blob_contributor" {
  scope                = azurerm_storage_container.preview_artifacts.resource_manager_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.preview_identity.principal_id
}

resource "azurerm_federated_identity_credential" "preview_fic" {
  name                = "fic-finpay-preview-envs"
  resource_group_name = var.resource_group_name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.aks_oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.preview_identity.id
  subject             = "system:serviceaccount:preview-envs:preview-sa" 
}