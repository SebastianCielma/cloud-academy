output "cloud_run_url" {
  description = "The public URL of the Cloud Run service"
  value       = module.cloud_run.service_url
}