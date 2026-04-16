output "alb_sg_id" {
  description = "ID of the ALB Security Group"
  value       = aws_security_group.alb_sg.id
}

output "jenkins_ec2_sg_id" {
  description = "ID of the EC2 Security Group"
  value       = aws_security_group.jenkins_ec2_sg.id
}

output "jenkins_instance_profile_name" {
  description = "Name of the IAM Instance Profile for Jenkins"
  value       = aws_iam_instance_profile.jenkins_profile.name
}