output "bastion_security_group_id" {
  description = "The ID of the Bastion security group"
  value       = aws_security_group.bastion.id
}

output "bastion_role_arn" {
  description = "The ARN of the Bastion IAM role"
  value       = aws_iam_role.bastion.arn
}