locals {
  name_prefix = "terraops-${var.environment}"
}

data "azurerm_resource_group" "academy" {
  name = var.resource_group_name
}

data "azurerm_subnet" "public" {
  name                 = "${local.name_prefix}-public"
  virtual_network_name = "${local.name_prefix}-vnet"
  resource_group_name  = data.azurerm_resource_group.academy.name
}

resource "tls_private_key" "academy_api" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_public_ip" "academy_api" {
  name                = "${local.name_prefix}-academy-api-pip"
  location            = data.azurerm_resource_group.academy.location
  resource_group_name = data.azurerm_resource_group.academy.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = var.environment
    ManagedBy   = "terraops"
  }
}

resource "azurerm_network_interface" "academy_api" {
  name                = "${local.name_prefix}-academy-api-nic"
  location            = data.azurerm_resource_group.academy.location
  resource_group_name = data.azurerm_resource_group.academy.name

  ip_configuration {
    name                          = "public"
    subnet_id                     = data.azurerm_subnet.public.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.academy_api.id
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "terraops"
  }
}

resource "azurerm_linux_virtual_machine" "academy_api" {
  name                = "${local.name_prefix}-academy-api"
  location            = data.azurerm_resource_group.academy.location
  resource_group_name = data.azurerm_resource_group.academy.name
  size                = var.vm_size
  admin_username      = var.admin_username

  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.academy_api.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.academy_api.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud_init.sh.tpl", {
    environment  = var.environment
    app_port     = var.app_port
    database_url = var.database_url
  }))

  tags = {
    Environment = var.environment
    ManagedBy   = "terraops"
  }
}
