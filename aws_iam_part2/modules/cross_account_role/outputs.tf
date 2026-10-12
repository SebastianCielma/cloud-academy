output "role_arn" {
  description = "ARN of the created cross-account role"
  value       = aws_iam_role.this.arn
}