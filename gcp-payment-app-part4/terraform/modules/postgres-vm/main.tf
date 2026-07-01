resource "google_service_account" "postgres_sa" {
  account_id   = "postgres-vm-sa"
  display_name = "PostgreSQL VM Service Account"
  project      = var.project_id
}

resource "google_compute_firewall" "allow_ssh_iap" {
  name    = "${var.network_name}-allow-ssh-iap"
  network = var.network_name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["postgres-db"]
}

resource "google_compute_firewall" "allow_postgres_internal" {
  name    = "${var.network_name}-allow-postgres-internal"
  network = var.network_name
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  source_ranges = ["10.1.0.0/16"] 
  target_tags   = ["postgres-db"]
}

resource "google_compute_instance" "postgres_vm" {
  name         = "payment-db-vm"
  machine_type = "e2-medium"
  zone         = "${var.region}-a"
  project      = var.project_id

  tags = ["postgres-db"]

  metadata = {
    startup-script = <<-EOF
      #!/bin/bash
      mkdir -p /var/backups/postgresql
      chown postgres:postgres /var/backups/postgresql

      cat << 'SCRIPT' > /usr/local/bin/db-backup.sh
      ${file("${path.module}/db-backup.sh")}
      SCRIPT

      chmod +x /usr/local/bin/db-backup.sh

      (crontab -l 2>/dev/null | grep -v db-backup.sh ; echo "0 2 * * * /usr/local/bin/db-backup.sh") | crontab -
    EOF
  }

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 50
      type  = "pd-standard" 
    }
  }

  network_interface {
    network    = var.network_name
    subnetwork = var.subnet_name
  }

  service_account {
    email  = google_service_account.postgres_sa.email
    scopes = ["cloud-platform"]
  }
}