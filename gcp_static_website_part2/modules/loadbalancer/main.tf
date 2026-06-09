resource "google_compute_backend_bucket" "website_backend" {
  name        = "${var.prefix}-backend"
  bucket_name = var.bucket_name
  enable_cdn  = true
}

resource "google_compute_url_map" "website_map" {
  name            = "${var.prefix}-url-map"
  default_service = google_compute_backend_bucket.website_backend.id
}

resource "google_compute_target_http_proxy" "website_proxy" {
  name    = "${var.prefix}-http-proxy"
  url_map = google_compute_url_map.website_map.id
}

resource "google_compute_global_forwarding_rule" "website_forwarding_rule" {
  name                  = "${var.prefix}-forwarding-rule"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  target                = google_compute_target_http_proxy.website_proxy.id
  port_range            = "80"
  labels                = var.tags
}