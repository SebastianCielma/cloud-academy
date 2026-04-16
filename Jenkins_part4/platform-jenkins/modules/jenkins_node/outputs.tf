output "instance_id" {
  description = "ID of the Jenkins EC2 instance"
  value       = aws_instance.jenkins_server.id
}

output "private_ip" {
  description = "Private IP of the Jenkins EC2 instance"
  value       = aws_instance.jenkins_server.private_ip
}