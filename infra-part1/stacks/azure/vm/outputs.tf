output "public_ip_address" {
  value = azurerm_public_ip.academy_api.ip_address
}

output "ssh_private_key_pem" {
  value     = tls_private_key.academy_api.private_key_pem
  sensitive = true
}
