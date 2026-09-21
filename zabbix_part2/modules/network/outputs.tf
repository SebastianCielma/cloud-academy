output "zabbix_server_sg_id" {
  description = "ID of the Zabbix Server Security Group"
  value       = aws_security_group.zabbix_server_sg.id
}

output "zabbix_agent_sg_id" {
  description = "ID of the Zabbix Agent Security Group"
  value       = aws_security_group.zabbix_agent_sg.id
}

output "subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public_subnet.id
}

output "rds_subnet_group_name" {
  value = aws_db_subnet_group.rds_subnet_group.name
}