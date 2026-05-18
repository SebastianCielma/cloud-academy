resource "azurerm_container_app_environment" "env" {
  name                       = "cae-helloapp-prod"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  log_analytics_workspace_id = var.log_analytics_workspace_id
  infrastructure_subnet_id   = var.subnet_id
  tags                       = var.common_tags
}

resource "azurerm_container_app" "app" {
  name                         = "ca-helloapp-prod"
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  tags                         = var.common_tags

  ingress {
    external_enabled = true
    target_port      = 8080
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  secret {
    name  = "acr-password"
    value = var.acr_password
  }

  registry {
    server               = var.acr_login_server
    username             = var.acr_username
    password_secret_name = "acr-password"
  }

template {
    min_replicas = 1
    max_replicas = 3

    container {
      name   = "helloapp"
      image  = "${var.acr_login_server}/helloapp:v1"
      cpu    = 0.25
      memory = "0.5Gi"
    }

    custom_scale_rule {
      name             = "cpu-scaling-rule"
      custom_rule_type = "cpu"
      metadata = {
        type  = "Utilization"
        value = "50"
      }
      #
    }
  }