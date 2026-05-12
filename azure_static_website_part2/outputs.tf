output "website_url" {
  description = "The public URL to access the static website via Front Door."
  value       = "https://${module.cdn_frontdoor.frontdoor_endpoint_hostname}"
}