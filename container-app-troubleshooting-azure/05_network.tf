######################
# VNET
######################
# VNet with 2 subnets: AppGW + Container Apps Environment
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.name}-vnet"
  address_space       = ["10.40.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Application Gateway requires a dedicated subnet (any name except "GatewaySubnet" is fine here)
resource "azurerm_subnet" "snet_appgw" {
  name                 = "appgw-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.40.0.0/24"]
}

# Container Apps Environment dedicated subnet
resource "azurerm_subnet" "snet_aca" {
  name                 = "aca-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.40.10.0/24"]

  delegation {
    name = "aca-delegation"
    service_delegation {
      name = "Microsoft.App/environments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

######################
# NAT GATEWAY
######################
# NAT Gateway
resource "azurerm_nat_gateway" "nat" {
  name                = "${var.name}-natgw"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway_public_ip_association" "nat_pip_assoc" {
  nat_gateway_id       = azurerm_nat_gateway.nat.id
  public_ip_address_id = azurerm_public_ip.nat_pip.id
}

# Attach NAT GW to the ACA subnet
resource "azurerm_subnet_nat_gateway_association" "aca_nat_assoc" {
  subnet_id      = azurerm_subnet.snet_aca.id
  nat_gateway_id = azurerm_nat_gateway.nat.id
}

