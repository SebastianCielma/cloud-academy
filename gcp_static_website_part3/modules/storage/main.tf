resource "google_storage_bucket" "website" {
  name                        = var.bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  labels                      = var.tags
  force_destroy               = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }
}

resource "google_storage_bucket_object" "index" {
  name   = "index.html"
  bucket = google_storage_bucket.website.name
  source = var.index_html_path
}

resource "google_storage_bucket_object" "error" {
  name   = "404.html"
  bucket = google_storage_bucket.website.name
  source = var.error_html_path
}

resource "google_storage_bucket_object" "error_4xx" {
  name   = "4xx.html"
  bucket = google_storage_bucket.website.name
  source = var.html_4xx_path
}

resource "google_storage_bucket_object" "error_5xx" {
  name   = "5xx.html"
  bucket = google_storage_bucket.website.name
  source = var.html_5xx_path
}

resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.website.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

resource "google_storage_bucket" "logs_bucket" {
  name                        = var.log_bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
  labels                      = var.tags

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_logging_project_sink" "lb_logs_sink" {
  name        = "${var.bucket_name}-lb-logs-sink"
  destination = "storage.googleapis.com/${google_storage_bucket.logs_bucket.name}"

  filter                 = "resource.type=\"http_load_balancer\""
  unique_writer_identity = true
}

resource "google_storage_bucket_iam_member" "log_writer" {
  bucket = google_storage_bucket.logs_bucket.name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.lb_logs_sink.writer_identity
}