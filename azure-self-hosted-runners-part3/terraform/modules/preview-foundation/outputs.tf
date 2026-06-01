output "managed_identity_client_id" {
  value = azurerm_user_assigned_identity.preview_identity.client_id
}