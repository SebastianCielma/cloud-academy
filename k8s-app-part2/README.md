# Nginx App — Kubernetes Helm Chart

Helm chart that deploys an Nginx web server on Kubernetes with basic auth, custom config, and persistent storage.

## What's Inside

| Template         | Purpose                                        |
|------------------|-------------------------------------------------|
| `deployment.yaml` | Nginx pod with resource limits and volume mounts |
| `service.yaml`    | LoadBalancer service exposing port 80            |
| `configmap.yaml`  | Custom `nginx.conf` with basic auth and `/health` endpoint |
| `secret.yaml`     | `.htpasswd` credentials (username + password)    |
| `pvc.yaml`        | 1Gi PersistentVolumeClaim for served content     |

## Prerequisites

- Kubernetes cluster (Minikube, EKS, etc.)
- Helm 3
- Docker image pushed to AWS ECR (or use default `nginx:latest`)

## Quick Start

### 1. Push image to ECR (optional)

```bash
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com
docker tag nginx:latest <account-id>.dkr.ecr.<region>.amazonaws.com/nginx-app:latest
docker push <account-id>.dkr.ecr.<region>.amazonaws.com/nginx-app:latest
```

### 2. Install the chart

```bash
helm install my-nginx ./nginx-app \
  --set auth.password='$(openssl passwd -apr1 yourpassword)'
```

To use an ECR image:

```bash
helm install my-nginx ./nginx-app \
  --set image.repository=<account-id>.dkr.ecr.<region>.amazonaws.com/nginx-app \
  --set image.tag=latest \
  --set auth.password='$(openssl passwd -apr1 yourpassword)'
```

### 3. Access the app

```bash
# Minikube
minikube service my-nginx-service

# Other clusters
kubectl get svc my-nginx-service
```

Login with the credentials set in `auth.username` / `auth.password`.

## Configuration

| Parameter              | Default   | Description             |
|------------------------|-----------|-------------------------|
| `replicaCount`         | `1`       | Number of pods          |
| `image.repository`     | `nginx`   | Docker image            |
| `image.tag`            | `latest`  | Image tag               |
| `service.type`         | `LoadBalancer` | Service type       |
| `service.port`         | `80`      | Exposed port            |
| `auth.username`        | `admin`   | Basic auth username     |
| `auth.password`        | `""`      | Basic auth password (required) |
| `persistence.size`     | `1Gi`     | PVC storage size        |
| `resources.requests.cpu` | `100m`  | CPU request             |
| `resources.requests.memory` | `64Mi` | Memory request       |
| `resources.limits.cpu` | `250m`    | CPU limit               |
| `resources.limits.memory` | `128Mi` | Memory limit          |

## Useful Commands

```bash
helm list                        # List releases
helm upgrade my-nginx ./nginx-app  # Apply changes
helm uninstall my-nginx          # Remove
helm template ./nginx-app        # Preview rendered manifests
```
