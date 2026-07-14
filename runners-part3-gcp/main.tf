module "github_runners" {
  source = "./modules/github-runners"

  github_repository     = var.github_repository
  github_pat            = var.github_pat
  runner_namespace      = "actions-runner-system"
  runner_scale_set_name = "finpay-k8s-runner"
}