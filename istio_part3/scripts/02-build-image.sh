#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT"

docker build   --tag istio-part3/services:v1   --file apps/Dockerfile   .

kind load docker-image   istio-part3/services:v1   --name istio-part3
