# Public IP for Application Gateway
resource "azurerm_public_ip" "agw_pip" {
  name                = "${var.name}-agw-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Public IP for NAT Gateway (Standard, Static)
resource "azurerm_public_ip" "nat_pip" {
  name                = "${var.name}-nat-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
