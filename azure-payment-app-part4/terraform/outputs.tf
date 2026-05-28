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

# ---------------------------------------------------------
# Self-Hosted Runners Outputs
# ---------------------------------------------------------

output "arc_runners_namespace" {
  description = "Namespace where self-hosted runner pods are deployed"
  value       = module.self_hosted_runners.arc_runners_namespace
}

output "runner_scale_set_name" {
  description = "Name of the runner scale set Helm release"
  value       = module.self_hosted_runners.runner_scale_set_name
}

output "runner_validation_command" {
  description = "Command to validate runner pods in Kubernetes"
  value       = module.self_hosted_runners.kubectl_validation_command
}
