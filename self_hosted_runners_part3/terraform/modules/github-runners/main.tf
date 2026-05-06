# ---------------------------------------------------------
# Namespaces & Secrets for Isolation
# ---------------------------------------------------------

resource "kubernetes_namespace" "arc_systems" {
  metadata {
    name = "arc-systems"
  }
}

resource "kubernetes_namespace" "arc_runners" {
  metadata {
    name = "arc-runners"
    labels = {
      "purpose" = "ci-cd-runners"
    }
  }
}

resource "kubernetes_secret" "github_auth" {
  metadata {
    name      = "github-auth-secret"
    namespace = kubernetes_namespace.arc_runners.metadata[0].name
  }
  data = {
    github_token = var.github_pat
  }
  type = "Opaque"
}

# ---------------------------------------------------------
# Actions Runner Controller Helm Releases
# ---------------------------------------------------------

resource "helm_release" "arc_controller" {
  name       = "arc"
  namespace  = kubernetes_namespace.arc_systems.metadata[0].name
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set-controller"
  version    = "0.9.3" 
}

resource "helm_release" "arc_runner_set" {
  name       = "k8s-runner-set"
  namespace  = kubernetes_namespace.arc_runners.metadata[0].name
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set"
  version    = "0.9.3"

  depends_on = [
    helm_release.arc_controller, 
    kubernetes_secret.github_auth
  ]

  values = [
    <<-EOT
    githubConfigUrl: "${var.github_config_url}"
    githubConfigSecret: "${kubernetes_secret.github_auth.metadata[0].name}"
    runnerGroup: "default"
    
    # Define resource requests and limits for CI runner pods
    template:
      spec:
        containers:
        - name: runner
          image: ghcr.io/actions/actions-runner:latest
          command: ["/home/runner/run.sh"]
          resources:
            requests:
              cpu: "500m"
              memory: "512Mi"
            limits:
              cpu: "1000m"
              memory: "1Gi"
    EOT
  ]
}