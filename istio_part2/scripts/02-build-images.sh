#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${ISTIO_PART2_PROFILE:-istio-part1}"

cd "$ROOT"
for version in v1 v2; do
  docker build --tag "istio-part2/app:${version}" --build-arg "APP_VERSION=${version}" --file apps/Dockerfile apps
  minikube -p "$PROFILE" image load "istio-part2/app:${version}"
done

minikube -p "$PROFILE" image ls | grep 'istio-part2/app'
