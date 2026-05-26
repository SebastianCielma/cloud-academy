output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = module.aks.cluster_name
}

output "acr_login_server" {
  description = "Login server URL of the Azure Container Registry"
  value       = data.azurerm_container_registry.this.login_server
}

output "keyvault_uri" {
  description = "URI of the Key Vault"
  value       = module.keyvault.keyvault_uri
}

output "postgresql_fqdn" {
  description = "FQDN of the PostgreSQL Flexible Server"
  value       = module.postgresql.server_fqdn
}

output "postgresql_jdbc_url" {
  description = "JDBC connection string for the application"
  value       = module.postgresql.jdbc_connection_string
}

output "appgateway_public_ip" {
  description = "Public IP address of the Application Gateway"
  value       = module.appgateway.public_ip_address
}

output "log_analytics_workspace" {
  description = "Name of the Log Analytics Workspace"
  value       = module.monitoring.workspace_name
}
