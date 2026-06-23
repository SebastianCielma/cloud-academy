output "cluster_name" {
  value = google_container_cluster.private_cluster.name
}

output "cluster_location" {
  value = google_container_cluster.private_cluster.location
}