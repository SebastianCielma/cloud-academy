output "private_ip" {
  value = azurerm_network_interface.this.private_ip_address
}

output "vm_id" {
  value = azurerm_linux_virtual_machine.this.id
}

output "jdbc_connection_string" {
  value = "jdbc:postgresql://${azurerm_network_interface.this.private_ip_address}:5432/paymentdb"
}
