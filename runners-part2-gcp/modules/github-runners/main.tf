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

  set {
    name  = "template.spec.containers[0].name"
    value = "runner"
  }

  set {
    name  = "template.spec.containers[0].resources.requests.cpu"
    value = "500m"
  }
  
  set {
    name  = "template.spec.containers[0].resources.requests.memory"
    value = "512Mi"
  }
  
  set {
    name  = "template.spec.containers[0].resources.limits.cpu"
    value = "1000m"
  }
  
  set {
    name  = "template.spec.containers[0].resources.limits.memory"
    value = "1Gi"
  }
}