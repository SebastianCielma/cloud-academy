output "arc_systems_namespace" {
  description = "The namespace where Actions Runner Controller is deployed."
  value       = kubernetes_namespace.arc_systems.metadata[0].name
}

output "arc_runners_namespace" {
  description = "The namespace where the self-hosted runner pods are deployed."
  value       = kubernetes_namespace.arc_runners.metadata[0].name
}

output "runner_scale_set_name" {
  description = "The name of the deployed Helm release for the Runner Scale Set."
  value       = helm_release.arc_runner_set.name
}

output "kubectl_validation_command" {
  description = "Helpful command to validate runner pods execution."
  value       = "kubectl get pods -n ${kubernetes_namespace.arc_runners.metadata[0].name} -w"
}