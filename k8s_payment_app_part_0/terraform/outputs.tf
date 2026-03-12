output "rds_endpoint" {
  description = "RDS db"
  value       = module.database.db_endpoint
}

output "ecr_repository_urls" {
  description = "URLs of the ECR repositories"
  value       = module.ecr.repository_urls
}