output "aks_system_subnet_id" {
  value = azurerm_subnet.aks_system.id
}

output "jumpbox_subnet_id" {
  value = azurerm_subnet.jumpbox.id
}

output "bastion_subnet_id" {
  value = azurerm_subnet.bastion.id
}