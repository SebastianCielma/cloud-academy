output "account_a_app_role_arn" {
  description = "ARN of the Application Role in Account A"
  value       = aws_iam_role.app_role_a.arn
}

output "account_b_shared_role_arn" {
  description = "ARN of the Shared Data Role in Account B"
  value       = module.shared_data_role.role_arn
}

output "bucket_name" {
  description = "Name of the Account B S3 bucket"
  value       = aws_s3_bucket.shared_data.id
}