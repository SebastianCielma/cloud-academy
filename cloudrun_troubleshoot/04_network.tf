resource "google_compute_network" "vpc" {
  count                   = var.create_vpc_connector ? 1 : 0
  name                    = "${var.name}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  count         = var.create_vpc_connector ? 1 : 0
  name          = "${var.name}-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.subnet_region
  network       = google_compute_network.vpc[0].id
}

resource "google_vpc_access_connector" "connector" {
  count  = var.create_vpc_connector ? 1 : 0
  name   = "${var.name}-connector"
  region = var.region

  subnet {
    name = google_compute_subnetwork.subnet[0].name
  }

  machine_type  = "e2-micro"
  min_instances = 2
  max_instances = 3

  depends_on = [google_project_service.apis]
}
