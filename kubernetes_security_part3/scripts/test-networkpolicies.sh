#!/usr/bin/env bash
set -uo pipefail

if [[ "$(kubectl config current-context)" != "security-part3" ]]; then
  echo "ERROR: wrong Kubernetes context"
  exit 1
fi

API_IP=$(kubectl get pod -n payments -l app=part3-payment-api \
  -o jsonpath='{.items[0].status.podIP}')
DB_IP=$(kubectl get pod -n payments -l app=part3-postgres \
  -o jsonpath='{.items[0].status.podIP}')

echo "Payment API: $API_IP"
echo "Postgres:   $DB_IP"

failures=0

check() {
  local label="$1" expected="$2"
  shift 2

  if "$@" >/dev/null 2>&1; then
    actual="ALLOW"
  else
    actual="DENY"
  fi

  if [[ "$actual" == "$expected" ]]; then
    echo "PASS | $label | $actual"
  else
    echo "FAIL | $label | expected=$expected actual=$actual"
    failures=$((failures + 1))
  fi
}

check "frontend -> payment-api" ALLOW \
  kubectl exec -n part3-frontend part3-frontend -- \
  wget -q -T 3 -O /dev/null "http://${API_IP}:8080"

check "payment-api -> postgres" ALLOW \
  kubectl exec -n payments deployment/part3-payment-api \
  -c network-client -- nc -z -w 3 "$DB_IP" 5432

check "frontend -> postgres" DENY \
  kubectl exec -n part3-frontend part3-frontend -- \
  nc -z -w 3 "$DB_IP" 5432

check "orders -> postgres" DENY \
  kubectl exec -n orders part3-orders-client -- \
  nc -z -w 3 "$DB_IP" 5432

check "untrusted -> postgres" DENY \
  kubectl exec -n part3-untrusted part3-untrusted-client -- \
  nc -z -w 3 "$DB_IP" 5432

echo
if (( failures == 0 )); then
  echo "RESULT: ALL NETWORK TESTS PASSED"
else
  echo "RESULT: $failures TEST(S) FAILED"
  exit 1
fi
