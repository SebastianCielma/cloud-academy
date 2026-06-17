$ErrorActionPreference = "Stop"

terraform init

terraform apply -target="google_project_service.apis" -target="google_artifact_registry_repository.repo" -auto-approve
