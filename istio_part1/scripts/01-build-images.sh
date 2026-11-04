#!/usr/bin/env bash
set -euo pipefail

for service in api-gateway order-service payment-service inventory-service; do
  echo "BUILDING: $service"
  docker build \
    -f "apps/$service/Dockerfile" \
    -t "istio-part1/$service:v1" \
    .
done

echo "BUILD_STATUS: COMPLETED"
