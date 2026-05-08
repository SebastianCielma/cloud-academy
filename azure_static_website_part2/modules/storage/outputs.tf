output "web_endpoint_host" {
  description = "The primary web endpoint host for the static website"
  value       = azurerm_storage_account.static_web.primary_web_host
}