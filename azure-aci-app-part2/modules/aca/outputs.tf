output "app_fqdn" {
  description = "The FQDN of the Container App Ingress"
  value       = azurerm_container_app.app.ingress[0].fqdn
}