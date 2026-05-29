resource "azurerm_kubernetes_cluster" "this" {
  name                = "aks-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.project_name}-${var.environment}"
  kubernetes_version  = var.kubernetes_version
  tags                = var.tags

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  default_node_pool {
    name                = "system"
    vm_size             = var.vm_size
    enable_auto_scaling = true
    min_count           = var.min_count
    max_count           = var.max_count
    vnet_subnet_id      = var.aks_subnet_id
    zones               = ["2"]

    node_labels = {
      "environment" = var.environment
      "project"     = var.project_name
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    service_cidr      = "172.16.0.0/16"
    dns_service_ip    = "172.16.0.10"
    load_balancer_sku = "standard"
  }

  ingress_application_gateway {
    gateway_id = var.appgateway_id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

resource "azurerm_role_assignment" "keyvault_secrets_user" {
  scope                = var.keyvault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_kubernetes_cluster.this.key_vault_secrets_provider[0].secret_identity[0].object_id
}

# ---------------------------------------------------------
# Dedicated CI Runner Node Pool
# - Cluster Autoscaler manages scale-out/in based on pending pods
# - Taint prevents application pods from scheduling here
# - min_count=0 enables scale-to-zero when no CI jobs are running
# - mode="User" is required for scale-to-zero capability
# ---------------------------------------------------------

resource "azurerm_kubernetes_cluster_node_pool" "ci_runners" {
  name                  = "cirunners"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.ci_vm_size
  enable_auto_scaling   = true
  min_count             = var.ci_min_count
  max_count             = var.ci_max_count
  vnet_subnet_id        = var.aks_subnet_id
  zones                 = ["2"]
  mode                  = "User"

  node_labels = {
    "workload-type" = "ci-runner"
    "environment"   = var.environment
  }

  node_taints = [
    "workload-type=ci-runner:NoSchedule"
  ]

  tags = var.tags
}
