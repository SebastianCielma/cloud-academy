output "lb_ip_address" {
  description = "The public IP address of the global forwarding rule."
  value       = google_compute_global_forwarding_rule.website_forwarding_rule.ip_address
}