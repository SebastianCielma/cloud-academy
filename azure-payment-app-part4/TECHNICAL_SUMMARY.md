# Self-Hosted Runners Part 2 — Technical Summary

## Overview

This project deploys GitHub Actions self-hosted runners directly into the existing Azure AKS Kubernetes cluster from the Payment Platform project. It uses Actions Runner Controller (ARC) managed via Terraform and Helm to execute CI/CD pipelines internally.

---

## How Runners Were Deployed

Self-hosted runners were deployed into the existing AKS cluster using the **Actions Runner Controller (ARC)** — a Kubernetes-native solution provided by GitHub. The deployment consists of two main components:

1. **ARC Controller** (`gha-runner-scale-set-controller`) — deployed in the `arc-systems` namespace, this component watches for GitHub Actions workflow jobs and manages runner lifecycle.

2. **Runner Scale Set** (`gha-runner-scale-set`) — deployed in the `arc-runners` namespace, this defines the actual runner pods that execute CI jobs. Runners register with GitHub using a Personal Access Token (PAT) stored securely in a Kubernetes Secret.

---

## How Terraform and Helm Were Used

The solution follows a **modular Terraform structure**, extending the existing infrastructure:

```
terraform/
├── main.tf              # Root — references all modules including github-runners
├── providers.tf         # azurerm + helm + kubernetes providers
├── variables.tf         # All variables including github_pat (sensitive)
├── outputs.tf           # Includes runner validation outputs
└── modules/
    ├── aks/             # Existing AKS cluster module
    ├── network/         # Existing networking module
    ├── ...              # Other existing modules
    └── github-runners/  # NEW — ARC deployment module
        ├── main.tf      # Namespaces, secret, helm_releases
        ├── variables.tf # github_config_url, github_pat
        └── outputs.tf   # Namespace names, validation commands
```

### Key Design Decisions:

- **Separation of concerns**: The `github-runners` module is completely independent from application modules. It only depends on the AKS cluster being available.
- **Helm provider**: Uses AKS client certificate authentication (`kube_config` outputs from the AKS module).
- **Separate state**: Uses a dedicated Terraform state key (`payment-platform-part4/terraform.tfstate`) to avoid conflicts.
- **No hardcoded secrets**: The `github_pat` is marked as `sensitive` and provided via `TF_VAR_github_pat` environment variable.

---

## How the Pipeline Was Modified

The existing CI/CD pipeline was adapted for self-hosted runner execution:

### Before (hosted runners):
```yaml
runs-on: ubuntu-latest
```

### After (self-hosted K8s runners):
```yaml
runs-on: k8s-runner-set
```

### Pipeline characteristics:
- **Path filtering**: Only triggers on changes in `azure-payment-app-part4/**`
- **Monorepo-compatible**: Other folders' pipelines are not affected
- **Builds both apps**: `payment-api` and `payment-worker` using Maven
- **Optional Docker build**: Commented out section for building and pushing Docker images to ACR

---

## End-to-End Execution Flow

```
1. Developer pushes code to azure-payment-app-part4/
                    ↓
2. GitHub detects path match → triggers workflow
                    ↓
3. GitHub looks for runners with label "k8s-runner-set"
                    ↓
4. ARC Controller (in arc-systems namespace) receives job request
                    ↓
5. ARC creates a runner pod in arc-runners namespace
                    ↓
6. Runner pod registers with GitHub, picks up the job
                    ↓
7. Job executes: checkout → setup Java → Maven build
                    ↓
8. Runner pod completes job, reports status back to GitHub
                    ↓
9. ARC Controller cleans up the runner pod
```

---

## Limitations and Risks

| Limitation | Description |
|---|---|
| **No autoscaling** | Current setup uses a fixed runner scale set without HPA. Under heavy load, jobs may queue. |
| **Single runner set** | Only one runner label (`k8s-runner-set`). Cannot differentiate between light and heavy CI workloads. |
| **PAT-based auth** | GitHub PAT has an expiration date and requires manual rotation. GitHub Apps are more secure for production. |
| **No Docker-in-Docker** | Runner pods cannot build Docker images without additional configuration (DinD sidecar or Kaniko). |
| **Shared cluster resources** | CI jobs compete with production workloads for cluster resources, though they run in separate namespaces. |
| **No persistent caching** | Maven dependencies are downloaded fresh for each job, increasing build time. |

---

## Namespace Isolation Strategy

CI runners are deployed in dedicated namespaces separate from application workloads:

| Namespace | Purpose | Contents |
|---|---|---|
| `arc-systems` | ARC controller | Controller pod, CRDs, webhooks |
| `arc-runners` | CI runner pods | Ephemeral runner pods for job execution |
| `payment-prod` | Application workloads | payment-api, payment-worker, configs |

### Why CI workloads should NOT run in the same context as application pods:

1. **Resource contention**: CI builds are CPU/memory intensive and can starve production pods
2. **Security isolation**: CI executes arbitrary code from PRs; compromised runners should not access production secrets
3. **Blast radius**: A misbehaving CI job should not crash production services
4. **RBAC separation**: Runners need different permissions than application pods
5. **Observability**: Separate namespaces make it easy to monitor and debug CI vs app issues independently

---

## Answers to Required Questions

### 1. Why is it beneficial to run CI workloads inside Kubernetes instead of using hosted runners?

- **Cost reduction**: No per-minute billing for GitHub-hosted runners; use existing cluster capacity
- **Network proximity**: Runners are inside the cluster VNet, can access private resources (ACR, databases) without exposing them publicly
- **Customization**: Full control over runner environment, pre-installed tools, and caching strategies
- **Compliance**: Code and artifacts stay within your infrastructure, satisfying data residency requirements
- **Performance**: No cold-start delays; runners can leverage node-local caches

### 2. What is the role of Actions Runner Controller (ARC)?

ARC is a Kubernetes operator that:
- **Watches** for GitHub Actions workflow jobs targeted at self-hosted runners
- **Creates** ephemeral runner pods when jobs are queued
- **Registers** runner pods with GitHub for job execution
- **Cleans up** runner pods after job completion
- **Manages** the lifecycle, scaling, and health of runner pods

It consists of two Helm charts: the **controller** (management plane) and the **runner scale set** (data plane defining runner configuration).

### 3. How does GitHub route jobs to self-hosted runners?

GitHub uses a **label-matching system**:
1. Workflow specifies `runs-on: k8s-runner-set`
2. GitHub API checks for registered runners with matching labels
3. ARC controller polls GitHub API for pending jobs matching its runner set
4. When a match is found, ARC creates a runner pod with the correct labels
5. The runner pod registers with GitHub and picks up the job
6. After completion, the pod is terminated and deregistered

### 4. Why should CI workloads be isolated from application workloads?

- **Security**: CI jobs may execute untrusted code (e.g., from pull requests), which could attempt lateral movement to production services
- **Resource protection**: CI builds are resource-intensive and unpredictable; isolation prevents them from starving production pods
- **Failure isolation**: A crashing CI job should not affect production availability
- **Compliance**: Separation of concerns is a DevSecOps best practice; audit trails are cleaner when CI and app workloads are in different namespaces
- **Different scaling needs**: CI workloads are bursty; production workloads need stable resources

### 5. What risks exist when running untrusted CI code inside your cluster?

| Risk | Description | Mitigation |
|---|---|---|
| **Container escape** | Malicious code could exploit container runtime vulnerabilities | Use Pod Security Standards, disable privileged containers |
| **Secret exfiltration** | Runner pod could access Kubernetes secrets in other namespaces | RBAC policies, NetworkPolicies between namespaces |
| **Resource exhaustion** | Fork bombs or crypto-mining could consume all cluster resources | Resource limits on runner pods, namespace resource quotas |
| **Network lateral movement** | Runner could scan and attack internal services | NetworkPolicies restricting runner pod egress |
| **Supply chain attacks** | Compromised dependencies downloaded during CI builds | Image scanning, dependency pinning, isolated build environments |

### 6. How would you extend this solution to support multiple environments (dev/staging/prod)?

1. **Separate runner scale sets** per environment with different labels:
   ```yaml
   runs-on: k8s-runner-set-dev    # for dev builds
   runs-on: k8s-runner-set-prod   # for prod builds
   ```

2. **Environment-specific namespaces**: `arc-runners-dev`, `arc-runners-staging`, `arc-runners-prod`

3. **Different resource limits**: Smaller runners for dev, larger for production builds

4. **Terraform workspaces or separate tfvars**: Environment configuration per `.tfvars` file

5. **GitHub Environments**: Use GitHub environment protection rules to gate deployments

### 7. What limitations exist in this setup before introducing autoscaling?

- **Fixed capacity**: Number of concurrent jobs is limited by the runner scale set's `maxRunners` setting
- **Resource waste**: Runner pods may sit idle when no jobs are queued, consuming cluster resources
- **Queue delays**: During peak hours, jobs wait in queue if all runners are busy
- **No burst capability**: Cannot handle sudden spikes in CI demand (e.g., multiple developers pushing simultaneously)
- **Manual intervention**: Scaling requires changing Terraform configuration and reapplying

**Solution**: ARC supports `minRunners` and `maxRunners` configuration with automatic scale-up/scale-down based on job queue depth. Enabling this requires the `gha-runner-scale-set` chart's autoscaling configuration.

---

## Validation Commands

```bash
# Verify runner controller is running
kubectl get pods -n arc-systems

# Watch runner pods during job execution
kubectl get pods -n arc-runners -w

# Check runner logs
kubectl logs -n arc-runners -l app.kubernetes.io/component=runner -f

# Verify namespaces
kubectl get ns | grep arc

# Check Helm releases
helm list -n arc-systems
helm list -n arc-runners
```
