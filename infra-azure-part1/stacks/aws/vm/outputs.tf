output "public_ip" {
  value = aws_instance.academy_api.public_ip
}

output "health_url" {
  value = "http://${aws_instance.academy_api.public_ip}/health"
}

output "ready_url" {
  value = "http://${aws_instance.academy_api.public_ip}/ready"
}

