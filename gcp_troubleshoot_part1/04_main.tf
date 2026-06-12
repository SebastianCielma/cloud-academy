###################
# NETWOKING
###################

# VPC and Subnet
resource "google_compute_network" "vpc" {
  name                            = "${var.name}-vpc"
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  delete_default_routes_on_create = true
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.name}-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
}

resource "google_compute_route" "default_internet" {
  name             = "${var.name}-default-internet"
  network          = google_compute_network.vpc.id
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
}

resource "google_compute_address" "static_ip" {
  name   = "${var.name}-static-ip"
  region = var.region
}

###################
# INSTANCE
###################
# Ubuntu 22.04 (Jammy) image
data "google_compute_image" "ubuntu_2204" {
  family  = "ubuntu-2204-lts"
  project = "ubuntu-os-cloud"
}

# Compute Engine VM
resource "google_compute_instance" "vm" {
  name         = "${var.name}-vm"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["web", "ssh"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu_2204.self_link
      size  = 10
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id

    access_config {
      nat_ip = google_compute_address.static_ip.address
    }
  }

  # Using the project default compute service account (simple for lab)
  service_account {
    email  = null
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  depends_on = [
    google_project_service.compute_api,
    google_compute_route.default_internet
  ]
}
