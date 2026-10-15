output "role_arn" {
  description = "ARN of the bounded IAM role"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the bounded IAM role"
  value       = aws_iam_role.this.name
}