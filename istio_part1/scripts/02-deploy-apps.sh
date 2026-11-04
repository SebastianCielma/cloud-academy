#!/usr/bin/env bash
set -euo pipefail

kubectl apply -f manifests/base/00-namespace.yaml
kubectl apply -f manifests/base/01-serviceaccounts.yaml
kubectl apply -f manifests/base/02-deployments.yaml
kubectl apply -f manifests/base/03-services.yaml

kubectl rollout status deployment/api-gateway -n istio-demo --timeout=180s
kubectl rollout status deployment/order-service -n istio-demo --timeout=180s
kubectl rollout status deployment/payment-service -n istio-demo --timeout=180s
kubectl rollout status deployment/inventory-service -n istio-demo --timeout=180s

kubectl get pods,svc -n istio-demo
