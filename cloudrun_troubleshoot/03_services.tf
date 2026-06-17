resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "compute.googleapis.com",
    "artifactregistry.googleapis.com",
    "certificatemanager.googleapis.com",
    "dns.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "vpcaccess.googleapis.com"
  ])
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}
