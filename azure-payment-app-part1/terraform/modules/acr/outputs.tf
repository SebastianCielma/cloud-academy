output "login_server" {
  value = azurerm_container_registry.this.login_server
}

output "cicd_identity_client_id" {
  value = azurerm_user_assigned_identity.cicd_pusher.client_id
}

output "registry_id" {
  value = azurerm_container_registry.this.id
}