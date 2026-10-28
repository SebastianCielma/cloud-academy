#!/usr/bin/env bash
set -uo pipefail

NS=part3-admission
failures=0

test "$(kubectl config current-context)" = "security-part3" || exit 1

kubectl get namespace "$NS" >/dev/null || exit 1

check_denied() {
  local name="$1"
  local yaml="$2"
  local output

  output=$(printf '%s\n' "$yaml" | kubectl create \
    --dry-run=server -n "$NS" -f - 2>&1)
  local status=$?

  if [[ "$status" -ne 0 ]] && grep -Eqi \
    'denied|forbidden|policy|validation failed|violat' <<< "$output"; then
    echo "PASS | $name | DENY"
  else
    echo "FAIL | $name | expected DENY"
    echo "$output"
    failures=$((failures + 1))
  fi
}

check_denied "privileged container" '
apiVersion: v1
kind: Pod
metadata:
  name: part3-test-privileged
spec:
  containers:
    - name: app
      image: docker.io/library/nginx:1.27
      securityContext:
        privileged: true
'

check_denied "latest image" '
apiVersion: v1
kind: Pod
metadata:
  name: part3-test-latest
spec:
  containers:
    - name: app
      image: docker.io/library/nginx:latest
'

check_denied "untrusted registry" '
apiVersion: v1
kind: Pod
metadata:
  name: part3-test-untrusted
spec:
  containers:
    - name: app
      image: quay.io/example/app:1.0
'

echo
echo "=== AUDIT MODE: DEPLOYMENT WITHOUT LABELS ==="

AUDIT_OUTPUT=$(kubectl create --dry-run=server -n "$NS" -f - 2>&1 <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: part3-test-missing-labels
spec:
  replicas: 0
  selector:
    matchLabels:
      app: part3-test-missing-labels
  template:
    metadata:
      labels:
        app: part3-test-missing-labels
    spec:
      containers:
        - name: app
          image: docker.io/library/nginx:1.27
YAML
)
AUDIT_STATUS=$?

if [[ "$AUDIT_STATUS" -eq 0 ]]; then
  echo "PASS | missing labels | AUDIT (request allowed)"
else
  echo "FAIL | missing labels | expected AUDIT allow"
  echo "$AUDIT_OUTPUT"
  failures=$((failures + 1))
fi

echo
if (( failures == 0 )); then
  echo "RESULT: ALL KYVERNO TESTS PASSED"
else
  echo "RESULT: $failures TEST(S) FAILED"
  exit 1
fi
