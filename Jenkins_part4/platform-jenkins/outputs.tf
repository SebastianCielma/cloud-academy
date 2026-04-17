output "jenkins_url" {
  description = "The URL to access the Jenkins UI via the Application Load Balancer"
  value       = "http://${aws_lb.jenkins_alb.dns_name}"
}

output "jenkins_private_ip" {
  description = "Private IP address of the Jenkins EC2 instance"
  value       = module.jenkins_node.private_ip
}