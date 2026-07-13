resource "kubernetes_namespace" "arc_namespace" {
  metadata {
    name = var.runner_namespace
  }
}

resource "helm_release" "arc_controller" {
  name       = "arc"
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set-controller"
  namespace  = kubernetes_namespace.arc_namespace.metadata[0].name
  version    = "0.9.3"

  wait = true
}

resource "helm_release" "runner_scale_set" {
  name       = var.runner_scale_set_name
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set"
  namespace  = kubernetes_namespace.arc_namespace.metadata[0].name
  version    = "0.9.3"

  depends_on = [helm_release.arc_controller]

  set {
    name  = "githubConfigUrl"
    value = var.github_repository
  }

  set {
    name  = "githubConfigSecret.github_token"
    value = var.github_pat
  }


  values = [
    yamlencode({
      template = {
        spec = {
          containers = [{
            name    = "runner"
            image   = "ghcr.io/actions/actions-runner:latest"
            command = ["/home/runner/run.sh"]
            resources = {
              requests = {
                cpu    = "500m"
                memory = "512Mi"
              }
              limits = {
                cpu    = "1000m"
                memory = "1Gi"
              }
            }
          }]
        }
      }
    })
  ]
}