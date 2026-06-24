resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = var.registry_id
  format        = "DOCKER"
}

resource "google_service_account" "cicd_sa" {
  account_id   = var.sa_account_id
  display_name = "CI/CD Service Account for Artifact Registry Push"
}

resource "google_artifact_registry_repository_iam_member" "writer" {
  project    = google_artifact_registry_repository.repo.project
  location   = google_artifact_registry_repository.repo.location
  repository = google_artifact_registry_repository.repo.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.cicd_sa.email}"
}