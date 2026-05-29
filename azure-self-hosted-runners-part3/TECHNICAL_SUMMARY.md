# Self-Hosted Runners Part 3 — Technical Summary

## Overview

This project extends the GitHub self-hosted runner platform (Part 2) with **dynamic node autoscaling** for CI workloads on Azure AKS. When resource-intensive CI pipelines run in parallel, the AKS Cluster Autoscaler automatically provisions additional compute nodes in a dedicated CI node pool, ensuring builds complete without manual intervention.

---

## Cloud Platform & Autoscaling Mechanism

| Item | Value |
|---|---|
| **Cloud Platform** | Microsoft Azure |
| **Kubernetes Service** | Azure Kubernetes Service (AKS) |
| **Autoscaling Mechanism** | AKS Cluster Autoscaler (built-in) |
| **CI Runner Solution** | Actions Runner Controller (ARC) v0.9.3 |

### Why AKS Cluster Autoscaler?

AKS natively integrates Cluster Autoscaler into its node pool configuration. It is the **documented and supported** mechanism for automatically scaling nodes on AKS. Unlike Karpenter (which is the preferred choice for AWS/EKS), AKS does not support Karpenter — Cluster Autoscaler is the natural built-in path as stated in Microsoft's documentation.

### What Limitation Would Exist Without Autoscaling?

Without node autoscaling, the cluster has a **fixed number of nodes**. When heavy CI jobs request more CPU/memory than available, runner pods enter `Pending` state and never execute. Pipelines would stall indefinitely until an operator manually scales the node pool — defeating the purpose of CI automation.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    AKS Cluster                                │
│                                                               │
│  ┌─────────────────────────┐  ┌────────────────────────────┐ │
│  │  System Node Pool       │  │  CI Runner Node Pool       │ │
│  │  (min=1, max=3)         │  │  (min=0, max=3)            │ │
│  │                         │  │                            │ │
│  │  ┌──────────────┐       │  │  ┌──────────────────────┐  │ │
│  │  │ payment-api  │       │  │  │ arc-runner pod #1    │  │ │
│  │  │ payment-     │       │  │  │ (1500m CPU, 1Gi mem) │  │ │
│  │  │   worker     │       │  │  └──────────────────────┘  │ │
│  │  │ ingress      │       │  │  ┌──────────────────────┐  │ │
│  │  └──────────────┘       │  │  │ arc-runner pod #2    │  │ │
│  │                         │  │  │ (1500m CPU, 1Gi mem) │  │ │
│  │  No CI taint            │  │  └──────────────────────┘  │ │
│  │  App workloads only     │  │                            │ │
│  └─────────────────────────┘  │  Taint: workload-type=     │ │
│                               │    ci-runner:NoSchedule     │ │
│  ┌───────────────┐            │                            │ │
│  │ arc-systems   │            │  Cluster Autoscaler:       │ │
│  │ (controller)  │            │  Scales 0→3 based on       │ │
│  └───────────────┘            │  pending pod demand        │ │
│                               └────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

---

## How the Heavy Pipeline Creates Scheduling Pressure

### Resource Math

| Component | Value |
|---|---|
| CI Node VM size | Standard_D2s_v3 (2 vCPU, 8 GB RAM) |
| Allocatable CPU per node | ~1800m (after system reservations) |
| Runner pod CPU request | 1500m |
| **Runners per node** | **1** (1500m < 1800m, but 2×1500m > 1800m) |
| Parallel matrix jobs | 4 |
| **Nodes required** | **4** (but max_count=3, so 1 job queues) |

### Scheduling Pressure Flow

```
1. Pipeline triggers → 4 matrix jobs created
2. ARC creates 4 runner pods (each requesting 1500m CPU)
3. CI node pool has 0 nodes (scale-to-zero)
4. Pods enter Pending state (unschedulable)
5. Cluster Autoscaler detects pending pods with nodeSelector matching CI pool
6. Autoscaler provisions new nodes in cirunners pool (up to max=3)
7. As nodes become Ready, pods get scheduled (1 per node)
8. 4th pod waits until a previous job completes and frees a node
9. All jobs complete successfully
10. After idle period (~10 min), Autoscaler scales CI pool back to 0
```

---

## Workload Isolation Strategy

### Why CI Must Be Isolated from Production

CI workloads execute **arbitrary, user-defined code** from workflow files. GitHub explicitly recommends careful isolation of runner workloads from sensitive production services. Without isolation:

- CI builds could **starve production pods** of CPU/memory
- A compromised CI job could **access production secrets** or databases
- Build failures could **cascade to application availability**
- **Unpredictable resource usage** from CI makes capacity planning impossible

### Isolation Mechanisms Implemented

| Mechanism | Implementation | Purpose |
|---|---|---|
| **Dedicated namespace** | `arc-runners` (separate from `payment-prod`) | RBAC boundary, secret isolation |
| **Dedicated node pool** | `cirunners` with `mode=User` | Physical compute separation |
| **Taint** | `workload-type=ci-runner:NoSchedule` | Prevents app pods on CI nodes |
| **Toleration** | Runner pods tolerate the CI taint | Only runners schedule on CI nodes |
| **NodeSelector** | `workload-type: ci-runner` | Runners target only CI nodes |
| **Resource limits** | `cpu: 2000m`, `memory: 2Gi` per runner | Prevents runaway resource usage |

---

## Resource Configuration

### Runner Pod Resources

```yaml
resources:
  requests:
    cpu: "1500m"      # High request → creates scheduling pressure
    memory: "1Gi"     # Sufficient for Java Maven builds
  limits:
    cpu: "2000m"      # Burst allowed up to node capacity
    memory: "2Gi"     # Prevents OOM in heavy builds
```

### How Resource Configuration Affects CI Execution

- **Requests** determine scheduling: with 1500m CPU request, the scheduler needs a node with at least 1500m allocatable. On D2s_v3 (~1800m), only 1 runner fits.
- **Limits** cap burst usage: even if the node has spare CPU, a runner cannot exceed 2000m, preventing it from affecting system components.
- **Memory limits** prevent OOM scenarios during Maven builds with multiple dependency downloads.

### How It Relates to Cluster Capacity

- **System pool** (min=1, max=3): Reserved for application workloads. CI runners cannot schedule here due to missing toleration for the CI taint... actually the system pool has no taint, but runners have a nodeSelector that directs them to the CI pool.
- **CI pool** (min=0, max=3): Exclusively for CI. With 1 runner/node and max 3 nodes, the cluster supports up to 3 concurrent CI jobs before queuing.

---

## Validation Commands

```bash
# === Before triggering pipeline ===

# Check current node count (CI pool should be 0)
kubectl get nodes -l workload-type=ci-runner
# Expected: No resources found

# Check all nodes
kubectl get nodes -o wide

# === After triggering pipeline (push to azure-self-hosted-runners-part3/) ===

# Watch runner pods get created and go Pending → Running
kubectl get pods -n arc-runners -w

# Watch new CI nodes appear
kubectl get nodes -w

# See scheduling events (unschedulable → scheduled)
kubectl get events -n arc-runners --sort-by=.lastTimestamp | tail -20

# Describe a pending pod to see autoscaler annotation
kubectl describe pod <pending-pod-name> -n arc-runners

# Check Cluster Autoscaler activity
kubectl get events --field-selector source=cluster-autoscaler --sort-by=.lastTimestamp

# Check node count after scale-out
kubectl get nodes -l workload-type=ci-runner
# Expected: 1-3 nodes with label workload-type=ci-runner

# === After pipeline completes (~10 min idle) ===

# Verify scale-in back to 0
kubectl get nodes -l workload-type=ci-runner
# Expected: No resources found (scaled to zero)
```

---

## Answers to Required Questions

### 1. Why is node autoscaling necessary for resource-intensive CI workloads running on self-hosted runners?

Self-hosted CI runners consume real cluster compute resources. When CI pipelines are lightweight, a fixed-size cluster may have enough spare capacity. But when pipelines become heavy (parallel Maven builds, vulnerability scans, Docker image builds), the **fixed cluster capacity is quickly exhausted**.

Without node autoscaling:
- Runner pods enter `Pending` state when no capacity is available
- CI pipelines stall until an operator manually increases nodes
- This defeats the purpose of automation — CI should be self-service

Node autoscaling solves this by **dynamically adding compute capacity when pending CI pods are detected**, and releasing it when jobs finish. This provides elastic CI capacity without over-provisioning.

### 2. Why is pod autoscaling alone not sufficient in this scenario?

Pod autoscaling (HPA) scales the **number of pods**, but each pod still needs a **physical node** to run on. If the cluster has 2 nodes and all CPU is consumed by existing workloads, creating more pods just creates more `Pending` pods — none of them can actually execute.

The fundamental constraint is **compute capacity** (nodes), not pod count. Only **node autoscaling** can add the physical infrastructure needed to schedule pending pods.

Analogy: HPA is like creating more seats for a restaurant, but node autoscaling is like building a bigger restaurant. You can't seat people in chairs that don't fit in the building.

### 3. How did you design the heavy pipeline so that it reliably creates scheduling pressure?

Three mechanisms work together:

1. **High resource requests** (1500m CPU per runner pod): On `Standard_D2s_v3` nodes with ~1800m allocatable CPU, only 1 runner fits per node. This makes the pod-to-node mapping predictable.

2. **Matrix strategy with 4 partitions**: The pipeline creates 4 identical jobs running in parallel. Each job needs its own runner pod, and each pod needs its own node → 4 nodes required.

3. **Scale-to-zero CI pool**: The CI node pool starts at 0 nodes. When the pipeline triggers, ALL 4 pods are immediately unschedulable, creating maximum pressure on the autoscaler.

Combined: 4 pods × 1500m CPU each = 6000m total demand vs 0m available (empty CI pool) → guaranteed scheduling pressure.

### 4. What risks arise if CI workloads share capacity with production applications without isolation?

| Risk | Impact | Severity |
|---|---|---|
| **Resource starvation** | CI builds consume CPU/memory, causing production pod evictions or throttling | Critical |
| **Security exposure** | CI executes arbitrary code from PRs; could access production secrets via shared nodes | Critical |
| **Noisy neighbor** | Disk I/O from Maven downloads and Docker builds degrades application latency | High |
| **Unpredictable capacity** | CI load is bursty and unpredictable, making production capacity planning impossible | High |
| **Blast radius** | A crashing CI job (OOM, fork bomb) can take down the node running production pods | Critical |
| **Compliance violations** | Mixing CI and production on same nodes may violate security audit requirements | Medium |

### 5. Why is Karpenter a strong fit for EKS-based dynamic CI capacity, and why are Cluster Autoscaler-based approaches natural for AKS and GKE?

**Karpenter on EKS:**
- Karpenter is a Kubernetes-native autoscaler that provisions nodes based on **pod scheduling needs** rather than node group scaling policies.
- It can select the **optimal instance type** for each pod's resource requirements.
- It supports **consolidation** — moving pods to smaller instances and terminating over-provisioned ones.
- AWS developed and documents Karpenter as the preferred scaling solution for EKS (EKS Auto Mode is built on Karpenter).

**Cluster Autoscaler on AKS/GKE:**
- AKS and GKE **natively integrate** Cluster Autoscaler into their node pool configuration — it's a first-class, built-in feature.
- On AKS, you simply set `enable_auto_scaling = true` with `min_count` and `max_count` on the node pool — no additional components to install.
- Karpenter is **not available for AKS** — Cluster Autoscaler is the only supported path.
- For GKE Standard clusters, Cluster Autoscaler is similarly the documented built-in mechanism.

**Summary:** Karpenter offers more flexibility on AWS but is AWS-exclusive. For AKS and GKE, Cluster Autoscaler is the natural, vendor-supported solution that requires zero additional setup.

### 6. What evidence proves that autoscaling was triggered by CI workloads rather than by application traffic?

Multiple sources of evidence:

1. **Node labels**: New nodes have `workload-type=ci-runner` — this label only exists on the CI node pool, not the system pool. Application traffic scaling would add nodes to the system pool.

2. **Kubernetes events**: `kubectl get events --field-selector source=cluster-autoscaler` shows the autoscaler decision was triggered by pods in the `arc-runners` namespace, not application namespace.

3. **Pod descriptions**: `kubectl describe pod <runner-pod>` shows the pod was `Unschedulable` due to taint `workload-type=ci-runner:NoSchedule` — only CI pods tolerate this taint.

4. **Timing correlation**: Node provisioning timestamps correlate exactly with GitHub Actions job queue times, not with application traffic patterns.

5. **Node pool separation**: System pool node count remains constant while CI pool count increases — proving the scale-out is in the CI pool specifically.

### 7. How would you optimize this solution further to reduce cost after pipelines finish?

| Optimization | Implementation | Impact |
|---|---|---|
| **Scale-to-zero** (already implemented) | `ci_min_count = 0` | No CI nodes running when idle — zero cost |
| **Aggressive scale-down delay** | Configure `--scale-down-unneeded-time=5m` on Cluster Autoscaler | Nodes removed 5 min after last job instead of default 10 min |
| **Spot/Low-priority VMs** | Set `priority = "Spot"` on CI node pool | 60-90% cost reduction; acceptable for CI (non-critical) |
| **Smaller VM sizes** | Use `Standard_B2s` (burstable) for lightweight CI | Lower per-node cost for less demanding builds |
| **Maven dependency caching** | Persistent volume or GitHub Actions cache | Faster builds → shorter node usage → less cost |
| **Job consolidation** | Reduce parallelism when builds are fast enough | Fewer concurrent pods → fewer nodes needed |
| **Scheduled scaling** | Scale CI pool to 0 outside business hours via CronJob | Guaranteed zero cost overnight/weekends |

The most impactful optimization is **Spot VMs** — CI workloads are ephemeral and can tolerate interruption, making them ideal candidates for Spot pricing.

---

## Terraform Structure

```
azure-self-hosted-runners-part3/
├── payment-api/                     # Java Spring Boot API service
├── payment-worker/                  # Java Spring Boot worker service
├── helm/payment-platform/           # Helm chart for app deployment
├── TECHNICAL_SUMMARY.md             # This document
└── terraform/
    ├── main.tf                      # Root — all modules + runners
    ├── providers.tf                 # azurerm + helm + kubernetes
    ├── variables.tf                 # All vars including CI pool config
    ├── terraform.tfvars             # Production values
    ├── outputs.tf                   # Cluster + runner outputs
    └── modules/
        ├── aks/                     # AKS cluster + CI node pool
        │   ├── main.tf              # System pool + cirunners pool
        │   ├── variables.tf         # Includes ci_vm_size, ci_min/max_count
        │   ├── outputs.tf
        │   └── versions.tf
        ├── github-runners/          # ARC deployment
        │   ├── main.tf              # Controller + runner set with
        │   │                        # nodeSelector + tolerations
        │   ├── variables.tf
        │   └── outputs.tf
        ├── network/                 # VNet + subnets
        ├── monitoring/              # Log Analytics
        ├── keyvault/                # Key Vault
        ├── appgateway/              # Application Gateway
        ├── postgresql-vm/           # PostgreSQL on VM
        └── postgresql/              # PostgreSQL (legacy)
```
