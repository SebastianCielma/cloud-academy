resource "google_compute_network" "vpc" {
  name                    = "hello-vpc-tf"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet_1" {
  name                     = "hello-subnet-1-tf"
  region                   = var.region_1
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = "10.0.1.0/24"
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "subnet_2" {
  name                     = "hello-subnet-2-tf"
  region                   = var.region_2
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = "10.0.2.0/24"
  private_ip_google_access = true
}

resource "google_compute_subnetwork" "subnet_connector" {
  name                     = "hello-connector-subnet-tf"
  region                   = var.region_1
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = "10.0.3.0/28"
  private_ip_google_access = true
}

resource "google_compute_router" "router" {
  name    = "hello-router-tf"
  region  = var.region_1
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "hello-nat-tf"
  router                             = google_compute_router.router.name
  region                             = var.region_1
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_vpc_access_connector" "connector" {
  name          = "hello-conn-tf"
  region        = var.region_1
  subnet {
    name = google_compute_subnetwork.subnet_connector.name
  }
  machine_type  = "e2-micro"
  min_instances = 2
  max_instances = 3
}