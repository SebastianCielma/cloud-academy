output "private_ip_address" {
  description = "The private IP address of the database"
  value       = google_sql_database_instance.instance.private_ip_address
}

output "db_name" {
  value = google_sql_database.database.name
}

output "db_user" {
  value = google_sql_user.users.name
}

output "db_password" {
  value     = random_password.db_password.result
  sensitive = true
}