output "dev_role_arn" {
  description = "ARN of the created IAM role"
  value       = module.orders_app_role.role_arn
}

output "bucket_name" {
  description = "Name of the dynamically created S3 bucket"
  value       = aws_s3_bucket.orders_bucket.id
}

output "test_s3_command" {
  description = "Command to test S3 download using assumed role"
  value       = "aws s3 cp s3://${aws_s3_bucket.orders_bucket.id}/test-order.json ./test-order.json --region eu-central-1"
}