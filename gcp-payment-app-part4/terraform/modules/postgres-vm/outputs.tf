output "private_ip" {
  value       = google_compute_instance.postgres_vm.network_interface.0.network_ip
}