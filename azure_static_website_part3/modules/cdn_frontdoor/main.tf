resource "azurerm_cdn_frontdoor_profile" "fd" {
  name                = var.profile_name
  resource_group_name = var.resource_group_name
  sku_name            = "Standard_AzureFrontDoor"

  tags = var.tags
}

resource "azurerm_cdn_frontdoor_endpoint" "fd_endpoint" {
  name                     = "${var.profile_name}-ep"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd.id

  tags = var.tags
}

resource "azurerm_cdn_frontdoor_origin_group" "fd_origin_group" {
  name                     = "default-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd.id
  session_affinity_enabled = false

  load_balancing {
    additional_latency_in_milliseconds = 50
    sample_size                        = 4
    successful_samples_required        = 3
  }

  health_probe {
    path                = "/"
    request_type        = "HEAD"
    protocol            = "Http"
    interval_in_seconds = 100
  }
}

resource "azurerm_cdn_frontdoor_origin" "fd_origin" {
  name                           = "storage-origin"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.fd_origin_group.id
  enabled                        = true
  host_name                      = var.origin_host_name
  origin_host_header             = var.origin_host_name
  certificate_name_check_enabled = true
}

resource "azurerm_cdn_frontdoor_route" "fd_route" {
  name                          = "default-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.fd_endpoint.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.fd_origin_group.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.fd_origin.id]
  supported_protocols           = ["Http", "Https"]
  patterns_to_match             = ["/*"]
  forwarding_protocol           = "MatchRequest"
  link_to_default_domain        = true
  https_redirect_enabled        = true
}

resource "azurerm_cdn_frontdoor_firewall_policy" "waf" {
  name                              = "WafPolicyPart3"
  resource_group_name               = var.resource_group_name
  sku_name                          = "Standard_AzureFrontDoor"
  enabled                           = true
  mode                              = "Prevention"
  custom_block_response_status_code = 403

  custom_rule {
    name                           = "RateLimitRule"
    enabled                        = true
    priority                       = 100
    rate_limit_duration_in_minutes = 1
    rate_limit_threshold           = 100
    type                           = "RateLimitRule"
    action                         = "Block"

    match_condition {
      match_variable     = "RemoteAddr"
      operator           = "IPMatch"
      negation_condition = false
      match_values       = ["0.0.0.0/0"]
    }
  }
}

resource "azurerm_cdn_frontdoor_security_policy" "waf_link" {
  name                     = "WafSecurityPolicy"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd.id

  security_policies {
    firewall {
      cdn_frontdoor_firewall_policy_id = azurerm_cdn_frontdoor_firewall_policy.waf.id

      association {
        domain {
          cdn_frontdoor_domain_id = azurerm_cdn_frontdoor_endpoint.fd_endpoint.id
        }
        patterns_to_match = ["/*"]
      }
    }
  }
}