resource "google_compute_instance" "bastion" {
  name         = "gke-bastion"
  machine_type = "e2-micro"
  zone         = "${var.region}-a"
  tags         = ["bastion-iap"]
  labels       = var.tags 

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network    = var.network_name
    subnetwork = var.subnet_name
  }

  service_account {
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "allow-iap-ssh"
  network = var.network_name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"] 
  target_tags   = ["bastion-iap"]
}