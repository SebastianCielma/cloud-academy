######################
# AG
######################
# Application Gateway (WAF_v2)
resource "azurerm_application_gateway" "agw" {
  name                = "${var.name}-agw"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "gwipc"
    subnet_id = azurerm_subnet.snet_appgw.id
  }

  frontend_port {
    name = "http"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "public-fe"
  }

  backend_address_pool {
    name         = "aca-backend"
  }

  # Health probe hitting "/"
  probe {
    name                = "probe-http"
    protocol            = "Http"
    path                = "/"
    interval            = 15
    timeout             = 5
    unhealthy_threshold = 2
    match {
      status_code = ["200"]
    }
  }

  backend_http_settings {
    name                  = "http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
    probe_name            = "probe-http"
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "public-fe"
    frontend_port_name             = "http"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "rule-default"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "aca-backend"
    backend_http_settings_name = "http-settings"
    priority                   = 100
  }

  waf_configuration {
    enabled          = true
    firewall_mode    = "Prevention"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }

  depends_on = [azurerm_container_app.web]
}

