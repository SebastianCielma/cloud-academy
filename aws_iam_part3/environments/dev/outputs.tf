output "developer_boundary_arn" {
  description = "ARN of the Permission Boundary"
  value       = aws_iam_policy.developer_boundary.arn
}

output "developer_delegation_policy_arn" {
  description = "ARN of the policy forcing developers to attach the boundary when creating roles"
  value       = aws_iam_policy.developer_delegation_guardrail.arn
}

output "wildcard_role_arn" {
  description = "Role with Action:* bounded by developer-boundary"
  value       = module.overprivileged_developer_role.role_arn
}

output "s3_only_role_arn" {
  description = "Role with S3-only policy bounded by developer-boundary"
  value       = module.underprivileged_developer_role.role_arn
}

output "test_bucket_name" {
  description = "Bucket for testing S3 permissions"
  value       = aws_s3_bucket.boundary_test.id
}

output "scp_policy_json_preview" {
  description = "Generated JSON of the AWS Organizations SCP Guardrail policy"
  value       = data.aws_iam_policy_document.scp_guardrails.json
}