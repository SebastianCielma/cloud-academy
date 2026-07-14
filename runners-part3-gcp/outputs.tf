output "runner_namespace" {
  description = "The namespace containing the deployed runners."
  value       = module.github_runners.runner_namespace
}

output "runner_label" {
  description = "The label to use in your GitHub Actions workflows (runs-on field)."
  value       = module.github_runners.runner_scale_set_name
}