output "gke_cluster_name" {
  value = module.gke.cluster_name
}

output "db_private_ip" {
  value = module.cloudsql.private_ip_address
}

output "db_user" {
  value = module.cloudsql.db_user
}

output "db_password" {
  value     = module.cloudsql.db_password
  sensitive = true
}