output "network_id" {
  description = "The ID of the VPC network"
  value       = google_compute_network.vpc_network.id
}

output "network_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.vpc_network.name
}

output "subnet_name" {
  description = "The name of the subnetwork"
  value       = google_compute_subnetwork.subnet.name
}