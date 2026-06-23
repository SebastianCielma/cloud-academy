resource "google_container_cluster" "private_cluster" {
  name                     = "gke-private-cluster"
  location                 = "${var.region}-a"
  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  network    = var.network_id
  subnetwork = var.subnet_id

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pod_range_name
    services_secondary_range_name = var.service_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.bastion_cidr
      display_name = "bastion-subnet"
    }
  }

  resource_labels = var.tags
}

resource "google_container_node_pool" "private_nodes" {
  name       = "private-node-pool"
  cluster    = google_container_cluster.private_cluster.id
  node_count = 1

  node_config {
    machine_type = "e2-medium"
    labels       = var.tags

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}