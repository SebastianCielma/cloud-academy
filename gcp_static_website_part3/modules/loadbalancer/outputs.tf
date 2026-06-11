output "lb_ip_address" {
  description = "The public IP address of the HTTPS load balancer."
  value       = google_compute_global_forwarding_rule.https_forwarding_rule.ip_address
}