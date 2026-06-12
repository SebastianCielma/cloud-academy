output "vm_public_ip" {
  description = "Static external IP address of the VM."
  value       = google_compute_address.static_ip.address
}

output "vm_name" {
  description = "Name of the Compute Engine instance."
  value       = google_compute_instance.vm.name
}

output "nginx_url" {
  description = "URL to access the Nginx default page."
  value       = "http://${google_compute_address.static_ip.address}"
}
