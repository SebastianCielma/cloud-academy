output "public_ip" {
  description = "Public IP of the Zabbix Server"
  value       = aws_instance.server.public_ip
}

output "private_ip" {
  description = "Private IP of the Zabbix Server"
  value       = aws_instance.server.private_ip
}