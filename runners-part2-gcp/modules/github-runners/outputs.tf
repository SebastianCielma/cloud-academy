output "runner_namespace" {
  description = "The created namespace where runners are deployed."
  value       = kubernetes_namespace.arc_namespace.metadata[0].name
}

output "runner_scale_set_name" {
  description = "The configured label to use in GitHub Actions runs-on field."
  value       = var.runner_scale_set_name
}