output "resource_group_name" {
  value = azurerm_resource_group.academy.name
}

output "vnet_name" {
  value = azurerm_virtual_network.academy.name
}

output "subnet_name" {
  value = azurerm_subnet.public.name
}

output "network_security_group_name" {
  value = azurerm_network_security_group.academy_api.name
}
