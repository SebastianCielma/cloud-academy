output "alb_dns_name" {
  value = module.load_balancing.alb_dns_name
}

output "ecr_repository_url" {
  value = module.compute.ecr_repository_url
}

output "github_plan_role_arn" {
   value = module.cicd.plan_role_arn 
}

output "github_apply_role_arn" { 
  value = module.cicd.apply_role_arn
}