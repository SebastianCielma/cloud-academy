resource "google_compute_global_address" "private_ip_address" {
  name          = "payment-db-private-ip"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.network_id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

resource "random_password" "db_password" {
  length  = 16
  special = true
}

resource "google_sql_database_instance" "instance" {
  name             = "payment-db-instance"
  project          = var.project_id
  region           = var.region
  database_version = "POSTGRES_15"

  deletion_protection = false

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier              = var.db_tier
    availability_type = "REGIONAL" 

    ip_configuration {
      ipv4_enabled    = false 
      private_network = var.network_id
    }

    backup_configuration {
      enabled = true
    }
  }
}

resource "google_sql_database" "database" {
  name     = "paymentdb"
  instance = google_sql_database_instance.instance.name
  project  = var.project_id
}

resource "google_sql_user" "users" {
  name     = "paymentuser"
  instance = google_sql_database_instance.instance.name
  project  = var.project_id
  password = random_password.db_password.result
}