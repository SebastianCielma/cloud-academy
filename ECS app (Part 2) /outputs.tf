output "alb_dns_name" {
  value = module.load_balancing.alb_dns_name
}

output "ecr_repository_url" {
  value = module.compute.ecr_repository_url
}