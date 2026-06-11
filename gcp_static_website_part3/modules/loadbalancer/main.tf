resource "google_compute_security_policy" "armor_policy" {
  name        = "${var.prefix}-armor-policy"
  description = "Cloud Armor Edge policy with 100 req/min rate limit per IP"
  type        = "CLOUD_ARMOR_EDGE"

  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IDS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default allow rule"
  }

  rule {
    action   = "throttle"
    priority = "1000"
    match {
      versioned_expr = "SRC_IDS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Rate limit rule: 100 req/min per IP"
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(403)"
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
      enforce_on_key = "IP"
    }
  }
}

resource "google_compute_backend_bucket" "website_backend" {
  name                 = "${var.prefix}-backend"
  bucket_name          = var.bucket_name
  enable_cdn           = true
  edge_security_policy = google_compute_security_policy.armor_policy.id
}

resource "tls_private_key" "cert_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "app_cert" {
  private_key_pem = tls_private_key.cert_key.private_key_pem

  subject {
    common_name  = "static-website.local"
    organization = "Cloud Academy Senior Team"
  }

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "google_compute_ssl_certificate" "lb_crypto_cert" {
  name        = "${var.prefix}-self-signed-ssl"
  private_key = tls_private_key.cert_key.private_key_pem
  certificate = tls_self_signed_cert.app_cert.cert_pem
}

resource "google_compute_url_map" "website_map_https" {
  name            = "${var.prefix}-url-map-https"
  default_service = google_compute_backend_bucket.website_backend.id

  default_custom_error_response_policy {
    error_service = google_compute_backend_bucket.website_backend.id
    
    error_response_rule {
      match_response_codes = ["4xx"]
      path                 = "/4xx.html"
    }

    error_response_rule {
      match_response_codes = ["5xx"]
      path                 = "/5xx.html"
    }
  }
}

resource "google_compute_url_map" "http_redirect_map" {
  name = "${var.prefix}-redirect-map"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_https_proxy" "https_proxy" {
  name             = "${var.prefix}-https-proxy"
  url_map          = google_compute_url_map.website_map_https.id
  ssl_certificates = [google_compute_ssl_certificate.lb_crypto_cert.id]
}

resource "google_compute_global_forwarding_rule" "https_forwarding_rule" {
  name                  = "${var.prefix}-https-forwarding-rule"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  target                = google_compute_target_https_proxy.https_proxy.id
  port_range            = "443"
  labels                = var.tags
}

resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "${var.prefix}-http-proxy"
  url_map = google_compute_url_map.http_redirect_map.id
}

resource "google_compute_global_forwarding_rule" "http_forwarding_rule" {
  name                  = "${var.prefix}-http-forwarding-rule"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  target                = google_compute_target_http_proxy.http_proxy.id
  port_range            = "80"
  labels                = var.tags
}