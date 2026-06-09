resource "google_storage_bucket" "website" {
  name                        = var.bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  labels                      = var.tags

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

resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.website.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}