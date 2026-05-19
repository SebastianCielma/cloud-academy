###########################
# NETWORK SECURITY GROUP (AG)
###########################
# NSG for Application Gateway subnet
resource "azurerm_network_security_group" "nsg_appgw" {
  name                = "${var.name}-nsg-appgw"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  # OUTBOUND: do backendu (lepiej szerzej niż konkretny CIDR)
  security_rule {
    name                       = "Allow-AppGw-To-Backend-HTTP"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80"]           # lub ["443"] gdy backend HTTPS
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork" # lub "*" na labie
  }
}

resource "azurerm_subnet_network_security_group_association" "assoc_appgw" {
  subnet_id                 = azurerm_subnet.snet_appgw.id
  network_security_group_id = azurerm_network_security_group.nsg_appgw.id
}


##############################
# NETWORK SECURITY GROUP (ACA)
##############################
# NSG for ACA subnet (egress only; inbound zwykle zbędny przy internal ingress)
resource "azurerm_network_security_group" "nsg_aca" {
  name                = "${var.name}-nsg-aca"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  # Allow DNS to Azure resolver
  security_rule {
    name                       = "Allow-DNS"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefix      = "*"
    destination_address_prefix = "168.63.129.16"
  }

  # Allow egress to Internet via NAT (HTTP/HTTPS)
  security_rule {
    name                       = "Allow-HTTP-HTTPS-Outbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }
}

resource "azurerm_subnet_network_security_group_association" "assoc_aca" {
  subnet_id                 = azurerm_subnet.snet_aca.id
  network_security_group_id = azurerm_network_security_group.nsg_aca.id
}
