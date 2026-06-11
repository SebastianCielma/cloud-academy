output "bucket_name" {
  description = "The name of the created storage bucket."
  value       = google_storage_bucket.website.name
}

output "logs_bucket_name" {
  description = "The name of the logs storage bucket."
  value       = google_storage_bucket.logs_bucket.name
}