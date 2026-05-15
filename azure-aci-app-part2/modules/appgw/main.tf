resource "azurerm_public_ip" "appgw_pip" {
  name                = "pip-appgw-prod"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.common_tags
}

resource "azurerm_application_gateway" "appgw" {
  name                = "appgw-helloapp-prod"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.common_tags

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = var.subnet_id
  }

  frontend_port {
    name = "frontend-port-80"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "frontend-ip-config"
    public_ip_address_id = azurerm_public_ip.appgw_pip.id
  }

  backend_address_pool {
    name  = "aca-backend-pool"
    fqdns = [var.aca_fqdn]
  }

  backend_http_settings {
    name                  = "aca-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30

    pick_host_name_from_backend_address = false
    host_name                           = var.aca_fqdn
    probe_name                          = "aca-health-probe"
  }

  probe {
    name                = "aca-health-probe"
    protocol            = "Http"
    path                = "/health"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3

    pick_host_name_from_backend_http_settings = false
    host                                      = var.aca_fqdn

    match {
      status_code = ["200-399"]
    }
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend-ip-config"
    frontend_port_name             = "frontend-port-80"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "aca-backend-pool"
    backend_http_settings_name = "aca-http-settings"
    priority                   = 100
  }
}

resource "azurerm_monitor_diagnostic_setting" "appgw_logs" {
  name                       = "diag-appgw-prod"
  target_resource_id         = azurerm_application_gateway.appgw.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }

  enabled_log {
    category = "ApplicationGatewayPerformanceLog"
  }

  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}