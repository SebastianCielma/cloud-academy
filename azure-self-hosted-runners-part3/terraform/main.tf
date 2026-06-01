locals {
  project_name = "payment"
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

data "azurerm_container_registry" "this" {
  name                = var.registry_name
  resource_group_name = azurerm_resource_group.this.name
}

module "network" {
  source = "./modules/network"

  project_name        = local.project_name
  environment         = var.environment
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.vnet_address_space
  subnet_prefixes     = var.subnet_prefixes
  tags                = var.tags
}

module "monitoring" {
  source = "./modules/monitoring"

  project_name        = local.project_name
  environment         = var.environment
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  retention_days      = var.log_retention_days
  tags                = var.tags
}

module "postgresql_vm" {
  source = "./modules/postgresql-vm"

  project_name        = local.project_name
  environment         = var.environment
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  database_subnet_id  = module.network.database_subnet_id
  aks_subnet_cidr     = var.subnet_prefixes.aks
  db_username         = var.db_admin_username
  db_password         = var.db_admin_password
  tags                = var.tags
}

module "keyvault" {
  source = "./modules/keyvault"

  project_name         = local.project_name
  environment          = var.environment
  location             = azurerm_resource_group.this.location
  resource_group_name  = azurerm_resource_group.this.name
  vnet_id              = module.network.vnet_id
  security_subnet_id   = module.network.security_subnet_id
  db_password          = var.db_admin_password
  db_connection_string = module.postgresql_vm.jdbc_connection_string
  tags                 = var.tags
}

module "appgateway" {
  source = "./modules/appgateway"

  project_name        = local.project_name
  environment         = var.environment
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  public_subnet_id    = module.network.public_subnet_id
  tags                = var.tags
}

module "aks" {
  source = "./modules/aks"

  project_name               = local.project_name
  environment                = var.environment
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  vm_size                    = var.aks_vm_size
  node_count                 = var.aks_node_count
  min_count                  = var.aks_min_count
  max_count                  = var.aks_max_count
  aks_subnet_id              = module.network.aks_subnet_id
  appgateway_id              = module.appgateway.appgateway_id
  acr_id                     = data.azurerm_container_registry.this.id
  keyvault_id                = module.keyvault.keyvault_id
  log_analytics_workspace_id = module.monitoring.workspace_id
  tags                       = var.tags

  ci_vm_size   = var.ci_vm_size
  ci_min_count = var.ci_min_count
  ci_max_count = var.ci_max_count
}

resource "azurerm_private_dns_zone" "acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  name                  = "vnet-link-acr"
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  resource_group_name   = azurerm_resource_group.this.name
  virtual_network_id    = module.network.vnet_id
}

resource "azurerm_private_endpoint" "acr" {
  name                = "pe-${var.registry_name}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = module.network.security_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-acr"
    private_connection_resource_id = data.azurerm_container_registry.this.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  private_dns_zone_group {
    name                 = "acr-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr.id]
  }
}

resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "diag-aks"
  target_resource_id         = module.aks.cluster_id
  log_analytics_workspace_id = module.monitoring.workspace_id

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "kube-controller-manager"
  }

  enabled_log {
    category = "kube-scheduler"
  }

  enabled_log {
    category = "kube-audit-admin"
  }

  metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "appgateway" {
  name                       = "diag-appgateway"
  target_resource_id         = module.appgateway.appgateway_id
  log_analytics_workspace_id = module.monitoring.workspace_id

  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }

  metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "keyvault" {
  name                       = "diag-keyvault"
  target_resource_id         = module.keyvault.keyvault_id
  log_analytics_workspace_id = module.monitoring.workspace_id

  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"
  }
}

module "self_hosted_runners" {
  source = "./modules/github-runners"

  github_config_url = "https://github.com/SebastianCielma/cloud-academy"
  github_pat        = var.github_pat

  depends_on = [
    module.aks
  ]
}

module "preview_foundation" {
  source = "./modules/preview-foundation"

  resource_group_name = "rg-payment-platform"
  location            = "westeurope"
  
  aks_oidc_issuer_url = "https://westeurope.oic.prod-aks.azure.com/cda9a1f6-c3a2-40f6-a425-89316170fa38/eac3eb4a-0940-4e22-b7e6-630d3cfbad96/"
}

