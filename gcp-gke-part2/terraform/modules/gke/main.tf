resource "google_service_account" "default" {
  account_id   = "${var.cluster_name}-sa"
  display_name = "GKE Minimal Service Account"
}

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = "${var.region}-a"

  remove_default_node_pool = true
  initial_node_count       = 1

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  resource_labels = var.tags
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  cluster    = google_container_cluster.primary.name
  location   = google_container_cluster.primary.location
  node_count = 1

  node_config {
    machine_type    = "e2-medium"
    service_account = google_service_account.default.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    resource_labels = var.tags
  }
}