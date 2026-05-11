output "frontdoor_endpoint_hostname" {
  description = "The default host name of the Front Door endpoint."
  value       = azurerm_cdn_frontdoor_endpoint.fd_endpoint.host_name
}