# ---------------------------------------------------------
# GitHub Actions Runner Controller (ARC) for Azure AKS
# Deploys self-hosted runners into the existing Kubernetes cluster
# ---------------------------------------------------------

# ---------------------------------------------------------
# Namespaces — Isolation of CI workloads from app workloads
# ---------------------------------------------------------

resource "kubernetes_namespace" "arc_systems" {
  metadata {
    name = "arc-systems"

    labels = {
      "app.kubernetes.io/part-of" = "github-actions-runner-controller"
      "purpose"                   = "ci-cd-controller"
    }
  }
}

resource "kubernetes_namespace" "arc_runners" {
  metadata {
    name = "arc-runners"

    labels = {
      "app.kubernetes.io/part-of" = "github-actions-runner-controller"
      "purpose"                   = "ci-cd-runners"
    }
  }
}

# ---------------------------------------------------------
# Secret — GitHub PAT for runner authentication
# ---------------------------------------------------------

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
# Helm Release — Actions Runner Controller (ARC)
# ---------------------------------------------------------

resource "helm_release" "arc_controller" {
  name       = "arc"
  namespace  = kubernetes_namespace.arc_systems.metadata[0].name
  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set-controller"
  version    = "0.9.3"

  wait = true
}

# ---------------------------------------------------------
# Helm Release — Runner Scale Set (actual runner pods)
# ---------------------------------------------------------

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

    # Runner pods are scheduled ONLY on the dedicated CI node pool:
    # - nodeSelector targets nodes with label workload-type=ci-runner
    # - tolerations allow pods to schedule on tainted CI nodes
    # - Resource requests are set high (1500m CPU) so only 1 runner
    #   fits per Standard_D2s_v3 node (2 vCPU / ~1800m allocatable).
    #   Running 4 parallel jobs creates 4 pending pods, forcing
    #   Cluster Autoscaler to provision additional CI nodes.
    template:
      spec:
        nodeSelector:
          workload-type: ci-runner
        tolerations:
        - key: "workload-type"
          operator: "Equal"
          value: "ci-runner"
          effect: "NoSchedule"
        containers:
        - name: runner
          image: ghcr.io/actions/actions-runner:latest
          command: ["/home/runner/run.sh"]
          resources:
            requests:
              cpu: "1200m"
              memory: "1Gi"
            limits:
              cpu: "2000m"
              memory: "2Gi"
    EOT
  ]

}
