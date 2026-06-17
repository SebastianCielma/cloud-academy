resource "google_cloud_run_service" "web" {
  name     = "${var.name}-web"
  location = var.region

  template {
    metadata {
      annotations = merge(
        {
          "autoscaling.knative.dev/minScale" = tostring(var.min_instances)
          "autoscaling.knative.dev/maxScale" = tostring(var.max_instances)
        },
        var.create_vpc_connector ? {
          "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.connector[0].id
          "run.googleapis.com/vpc-access-egress"    = "private-ranges-only"
        } : {}
      )
    }

    spec {
      containers {
        image = var.web_image

        ports {
          container_port = 8080
        }

        resources {
          limits = {
            cpu    = "1"
            memory = "512Mi"
          }
        }
      }

      service_account_name  = google_service_account.run_sa.email
      container_concurrency = var.autoscale_metric == "concurrency" ? var.autoscale_target : 80
      timeout_seconds       = 300
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  autogenerate_revision_name = true

  depends_on = [
    google_project_service.apis,
    google_project_iam_member.ar_reader,
    google_project_iam_member.ar_reader_compute,
  ]
}

resource "google_cloud_run_service_iam_member" "public_access" {
  service  = google_cloud_run_service.web.name
  location = google_cloud_run_service.web.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}
