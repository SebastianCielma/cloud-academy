output "cloud_run_url" {
  value = google_cloud_run_service.web.status[0].url
}

output "lb_ip_address" {
  value = google_compute_global_address.lb_ip.address
}

output "service_account_email" {
  value = google_service_account.run_sa.email
}
