output "zabbix_server_public_ip" {
  description = "Public IP of the Zabbix Server to access the Web UI and SSH"
  value       = module.zabbix_server.public_ip
}

output "zabbix_agents_public_ips" {
  description = "Public IPs of the Zabbix Agents for SSH troubleshooting"
  value       = module.zabbix_agents[*].public_ip
}

output "zabbix_agents_private_ips" {
  description = "Private IPs of the Zabbix Agents"
  value       = module.zabbix_agents[*].private_ip
}

output "aws_access_key_id" {
  value       = aws_iam_access_key.zabbix_cloudwatch_key.id
  description = "Access Key Zabbix AWS API"
}

output "aws_secret_access_key" {
  value       = aws_iam_access_key.zabbix_cloudwatch_key.secret
  sensitive   = true
  description = "Secret Key Zabbix AWS API"
}