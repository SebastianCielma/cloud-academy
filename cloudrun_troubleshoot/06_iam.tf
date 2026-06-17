resource "google_service_account" "run_sa" {
  account_id   = "${var.name}-run-sa"
  display_name = "Cloud Run runtime SA"
}

resource "google_project_iam_member" "ar_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.run_sa.email}"
}

data "google_project" "this" {}

resource "google_project_iam_member" "ar_reader_compute" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${data.google_project.this.number}-compute@developer.gserviceaccount.com"
}
