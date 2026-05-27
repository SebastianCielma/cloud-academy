output "aks_cluster_name" {
  value = module.aks.cluster_name
}

output "acr_login_server" {
  value = data.azurerm_container_registry.this.login_server
}

output "keyvault_uri" {
  value = module.keyvault.keyvault_uri
}

output "postgresql_vm_private_ip" {
  value = module.postgresql_vm.private_ip
}

output "postgresql_jdbc_url" {
  value = module.postgresql_vm.jdbc_connection_string
}

output "appgateway_public_ip" {
  value = module.appgateway.public_ip_address
}

output "log_analytics_workspace" {
  value = module.monitoring.workspace_name
}
