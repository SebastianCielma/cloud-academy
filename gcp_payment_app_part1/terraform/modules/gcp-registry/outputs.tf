output "registry_url" {
  value = "${google_artifact_registry_repository.repo.location}-docker.pkg.dev/${google_artifact_registry_repository.repo.project}/${google_artifact_registry_repository.repo.name}"
}

output "service_account_email" {
  value = google_service_account.cicd_sa.email
}