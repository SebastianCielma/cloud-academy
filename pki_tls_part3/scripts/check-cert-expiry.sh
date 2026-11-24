#!/usr/bin/env bash
set -euo pipefail

WARN_THRESHOLD_HOURS="${1:-2}"
NAMESPACE="${2:-apps}"

echo "=== Certificate Expiry Monitor (threshold: < ${WARN_THRESHOLD_HOURS}h) ==="
NOW_EPOCH=$(date -u +%s)
THRESHOLD_SEC=$((WARN_THRESHOLD_HOURS * 3600))
ALERTS=0

for cert in $(kubectl get certificates -n "${NAMESPACE}" -o jsonpath='{.items[*].metadata.name}'); do
  NOT_AFTER=$(kubectl get certificate "${cert}" -n "${NAMESPACE}" -o jsonpath='{.status.notAfter}')
  READY=$(kubectl get certificate "${cert}" -n "${NAMESPACE}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')

  if [[ -z "${NOT_AFTER}" ]]; then
    echo "[WARN] ${NAMESPACE}/${cert}: No notAfter timestamp (Ready=${READY})"
    continue
  fi

  EXP_EPOCH=$(python3 -c "from datetime import datetime; print(int(datetime.fromisoformat('${NOT_AFTER}'.replace('Z', '+00:00')).timestamp()))")
  REMAINING_SEC=$((EXP_EPOCH - NOW_EPOCH))
  REMAINING_MIN=$((REMAINING_SEC / 60))

  if [[ "${REMAINING_SEC}" -lt "${THRESHOLD_SEC}" ]]; then
    echo "[ALERT] Certificate ${NAMESPACE}/${cert} expires in ${REMAINING_MIN}m (${NOT_AFTER}) — below ${WARN_THRESHOLD_HOURS}h threshold!"
    ALERTS=$((ALERTS + 1))
  else
    echo "[OK]    Certificate ${NAMESPACE}/${cert} valid for ${REMAINING_MIN}m (${NOT_AFTER})"
  fi
done

echo "Total active expiry alerts: ${ALERTS}"
