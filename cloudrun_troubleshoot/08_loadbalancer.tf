resource "google_compute_global_address" "lb_ip" {
  name = "${var.name}-lb-ip"
}

resource "google_certificate_manager_certificate" "managed" {
  count = length(var.domain) > 0 ? 1 : 0

  name = "${var.name}-managed-cert"
  managed { domains = [var.domain] }
}

resource "google_compute_region_network_endpoint_group" "serverless_neg" {
  name                  = "${var.name}-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = google_cloud_run_service.web.name
  }
}

resource "google_compute_backend_service" "default" {
  name                  = "${var.name}-backend"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTPS"
  timeout_sec           = 30

  backend {
    group = google_compute_region_network_endpoint_group.serverless_neg.id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_url_map" "url_map" {
  name            = "${var.name}-url-map"
  default_service = google_compute_backend_service.default.id
}

resource "google_compute_target_http_proxy" "http_proxy" {
  name    = "${var.name}-http-proxy"
  url_map = google_compute_url_map.url_map.id
}

resource "google_compute_target_https_proxy" "https_proxy" {
  count   = length(var.domain) > 0 ? 1 : 0
  name    = "${var.name}-https-proxy"
  url_map = google_compute_url_map.url_map.id
  certificate_manager_certificates = [
    google_certificate_manager_certificate.managed[0].id
  ]
}

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${var.name}-http-fwd"
  ip_address            = google_compute_global_address.lb_ip.address
  port_range            = "80"
  target                = google_compute_target_http_proxy.http_proxy.id
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

resource "google_compute_global_forwarding_rule" "https" {
  count                 = length(var.domain) > 0 ? 1 : 0
  name                  = "${var.name}-https-fwd"
  ip_address            = google_compute_global_address.lb_ip.address
  port_range            = "443"
  target                = google_compute_target_https_proxy.https_proxy[0].id
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
