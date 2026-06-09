output "bucket_name" {
  description = "The name of the created storage bucket."
  value       = google_storage_bucket.website.name
}