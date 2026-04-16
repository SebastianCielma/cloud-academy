output "vpc_id" {
  description = "ID of the Jenkins VPC"
  value       = aws_vpc.jenkins_vpc.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = aws_subnet.private.id
}