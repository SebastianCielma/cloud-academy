output "bastion_name" {
  value = google_compute_instance.bastion.name
}

output "bastion_zone" {
  value = google_compute_instance.bastion.zone
}