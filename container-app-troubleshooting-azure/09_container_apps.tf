#########################
# CONTAINER ENVIRONMENT
#########################
# Container Apps Environment with VNet integration
resource "azurerm_container_app_environment" "env" {
  name                           = "${var.name}-env"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.rg.name
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.law.id
  internal_load_balancer_enabled = true
  infrastructure_subnet_id       = azurerm_subnet.snet_aca.id
  public_network_access          = "Disabled"
  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
    minimum_count         = 0
    maximum_count         = 300
  }
}

######################
# CONTAINER APP
######################
# Web Container App (internal ingress; fronted by App Gateway)
resource "azurerm_container_app" "web" {
  name                         = "${var.name}-web"
  resource_group_name          = azurerm_resource_group.rg.name
  container_app_environment_id = azurerm_container_app_environment.env.id
  revision_mode                = "Single"

  template {
    container {
      name   = "web"
      image  = "${azurerm_container_registry.acr.login_server}/samples/web:latest"
      cpu    = 0.5
      memory = "1.0Gi"


      liveness_probe {
        transport               = "HTTP"
        path                    = "/"
        port                    = var.container_port
        initial_delay           = 5
        interval_seconds        = 15
        timeout                 = 5
        failure_count_threshold = 3
      }
    }
  }

  ingress {
    allow_insecure_connections = true

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  tags = {
    app = "${var.name}-web"
  }
}


