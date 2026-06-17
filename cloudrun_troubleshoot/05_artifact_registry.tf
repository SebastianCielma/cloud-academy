resource "google_artifact_registry_repository" "repo" {
  location      = var.region
  repository_id = var.repo_name
  format        = "DOCKER"
  description   = "Images for ${var.name}"
  depends_on    = [google_project_service.apis]
}

