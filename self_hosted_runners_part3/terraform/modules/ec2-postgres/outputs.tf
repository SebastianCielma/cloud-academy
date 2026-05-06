output "private_ip" {
  description = "The internal IP address of the EC2 PostgreSQL instance"
  value       = aws_instance.postgres.private_ip
}
