output "cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.this.id
}

output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.this.name
}

output "kube_config_host" {
  description = "Kubernetes API server host"
  value       = azurerm_kubernetes_cluster.this.kube_config[0].host
  sensitive   = true
}

output "kube_config_client_certificate" {
  description = "Base64 encoded client certificate"
  value       = azurerm_kubernetes_cluster.this.kube_config[0].client_certificate
  sensitive   = true
}

output "kube_config_client_key" {
  description = "Base64 encoded client key"
  value       = azurerm_kubernetes_cluster.this.kube_config[0].client_key
  sensitive   = true
}

output "kube_config_cluster_ca_certificate" {
  description = "Base64 encoded cluster CA certificate"
  value       = azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate
  sensitive   = true
}

output "kubelet_identity_object_id" {
  description = "Object ID of the kubelet managed identity"
  value       = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

output "keyvault_secrets_provider_client_id" {
  description = "Client ID of the Key Vault secrets provider identity"
  value       = azurerm_kubernetes_cluster.this.key_vault_secrets_provider[0].secret_identity[0].client_id
}

output "node_resource_group" {
  description = "Auto-generated resource group for AKS nodes"
  value       = azurerm_kubernetes_cluster.this.node_resource_group
}
