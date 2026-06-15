resource "google_cloud_run_v2_service" "app" {
  name     = "hello-service-tf"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    containers {
      image = var.image_url
      resources {
        limits = {
          cpu    = "0.25"
          memory = "512Mi"
        }
      }
    }
    vpc_access {
      connector = var.connector_id
      egress    = "ALL_TRAFFIC"
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "public_access" {
  project  = google_cloud_run_v2_service.app.project
  location = google_cloud_run_v2_service.app.location
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}