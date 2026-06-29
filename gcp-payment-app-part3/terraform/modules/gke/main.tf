resource "google_service_account" "gke_sa" {
  account_id   = "payment-gke-sa"
  display_name = "Payment GKE Service Account"
  project      = var.project_id
}

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  deletion_protection = false


  remove_default_node_pool = true

  initial_node_count       = 1

  node_config {
    disk_size_gb = 50
    disk_type    = "pd-standard"
  }

  network    = var.network_id
  subnetwork = var.subnet_name

  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods-range"
    services_secondary_range_name = "gke-services-range"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false           
    master_ipv4_cidr_block  = "172.16.0.0/28" 
  }

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name     = "${var.cluster_name}-node-pool"
  location = var.region
  cluster  = google_container_cluster.primary.name
  project  = var.project_id

  autoscaling {
    min_node_count = 1
    max_node_count = 5
  }

  initial_node_count = 1

  node_config {
    service_account = google_service_account.gke_sa.email

    machine_type = "e2-standard-2"

    disk_size_gb    = 50
    disk_type       = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/trace.append"
    ]
  }
}