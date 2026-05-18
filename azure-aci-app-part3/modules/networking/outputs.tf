output "vnet_id" {
  value = azurerm_virtual_network.vnet.id
}

output "public_subnet_1_id" {
  value = azurerm_subnet.public_1.id
}

output "public_subnet_2_id" {
  value = azurerm_subnet.public_2.id
}

output "private_subnet_1_id" {
  value = azurerm_subnet.private_1.id
}

output "private_subnet_2_id" {
  value = azurerm_subnet.private_2.id
}