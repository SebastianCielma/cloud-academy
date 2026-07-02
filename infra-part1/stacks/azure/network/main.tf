locals {
  name_prefix = "terraops-${var.environment}"
}

resource "azurerm_resource_group" "academy" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = var.environment
    ManagedBy   = "terraops"
  }
}

resource "azurerm_virtual_network" "academy" {
  name                = "${local.name_prefix}-vnet"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.academy.location
  resource_group_name = azurerm_resource_group.academy.name

  tags = {
    Environment = var.environment
    ManagedBy   = "terraops"
  }
}

resource "azurerm_subnet" "public" {
  name                 = "${local.name_prefix}-public"
  resource_group_name  = azurerm_resource_group.academy.name
  virtual_network_name = azurerm_virtual_network.academy.name
  address_prefixes     = [var.subnet_cidr]
}

resource "azurerm_network_security_group" "academy_api" {
  name                = "${local.name_prefix}-academy-api"
  location            = azurerm_resource_group.academy.location
  resource_group_name = azurerm_resource_group.academy.name

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSH"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "terraops"
  }
}

resource "azurerm_subnet_network_security_group_association" "public" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.academy_api.id
}
