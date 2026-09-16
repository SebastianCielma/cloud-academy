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