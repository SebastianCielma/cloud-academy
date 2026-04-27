#!/usr/bin/env bash
set -euo pipefail

SERVICE=""
PORT=""
HEALTH_URL=""
MODE=""
WAIT_TIME=5 

# ==========================================
# LOGGING FUNCTIONS
# ==========================================
log_info() { echo "[INFO] $1"; }
log_warning() { echo "[WARNING] $1"; }
log_error() { echo "[ERROR] $1"; }

# ==========================================
# ARGUMENT PARSING
# ==========================================
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --service) SERVICE="$2"; shift 2 ;;
        --port) PORT="$2"; shift 2 ;;
        --health-url) HEALTH_URL="$2"; shift 2 ;;
        --mode) MODE="$2"; shift 2 ;;
        --wait) WAIT_TIME="$2"; shift 2 ;;
        *) 
            log_error "Unknown parameter: $1"
            exit 2 
            ;;
    esac
done

# Argument validation
if [[ -z "$SERVICE" || -z "$PORT" || -z "$HEALTH_URL" || -z "$MODE" ]]; then
    log_error "Missing required parameters."
    log_info "Usage: $0 --service <name> --port <port> --health-url <url> --mode <check|heal|diagnose> [--wait <seconds>]"
    exit 2
fi

if [[ "$MODE" != "check" && "$MODE" != "heal" && "$MODE" != "diagnose" ]]; then
    log_error "Invalid mode. Supported modes: check, heal, diagnose."
    exit 2
fi

# ==========================================
# CHECK FUNCTIONS
# ==========================================
check_service_status() {
    if systemctl is-active --quiet "$SERVICE"; then
        return 0
    else
        return 1
    fi
}

check_port_listening() {
    if ss -ltnp | grep -q ":${PORT}\b"; then
        return 0
    else
        return 1
    fi
}

check_health_endpoint() {
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL" || true)
    
    if [[ "$http_code" == "200" ]]; then
        return 0
    else
        return 1
    fi
}

perform_all_checks() {
    local all_good=true
    
    log_info "Checking service: $SERVICE"
    
    if check_service_status; then
        log_info "Service is active"
    else
        log_error "Service is not active"
        all_good=false
    fi

    if check_port_listening; then
        log_info "Port $PORT is listening"
    else
        log_error "Port $PORT is not listening"
        all_good=false
    fi

    if check_health_endpoint; then
        log_info "Health endpoint check passed"
    else
        log_error "Health endpoint check failed"
        all_good=false
    fi

    if [ "$all_good" = true ]; then
        return 0
    else
        return 1
    fi
}

# ==========================================
# DIAGNOSTIC FUNCTION
# ==========================================
diagnose() {
    local timestamp
    timestamp=$(date +"%Y-%m-%d-%H-%M-%S")
    local reports_dir="./reports"
    local report_file="${reports_dir}/${SERVICE}-${timestamp}.log"
    
    mkdir -p "$reports_dir"
    
    {
        echo "=== DIAGNOSTIC REPORT ==="
        echo "Timestamp: $(date)"
        echo "Service: $SERVICE"
        echo ""
        
        echo "--- 1. Service Status (systemctl status) ---"
        systemctl status "$SERVICE" --no-pager -l || true
        echo ""
        
        echo "--- 2. Recent Logs (journalctl) ---"
        journalctl -u "$SERVICE" --no-pager -n 50 || true
        echo ""
        
        echo "--- 3. Port Inspection (ss -ltnp) ---"
        ss -ltnp | grep ":${PORT}\b" || echo "No process listening on port $PORT."
        echo ""
        
        echo "--- 4. Health Endpoint Check (curl) ---"
        curl -v -s "$HEALTH_URL" || echo "Failed to connect to $HEALTH_URL"
        echo ""
        
        echo "--- 5. Summary of Actions Taken ---"
        if [[ "$MODE" == "heal" ]]; then
            echo "Action: Automated recovery (restart) attempted."
            echo "Result: Recovery failed. Validations did not pass after restart."
        else
            echo "Action: Manual diagnostics triggered via 'diagnose' mode."
        fi
        echo "========================="
    } > "$report_file"

    log_info "Diagnostic report saved to $report_file"
}

# ==========================================
# HEAL (RECOVERY) FUNCTION
# ==========================================
heal() {
    log_info "Starting health checks before recovery..."
    
    if perform_all_checks; then
        log_info "Service is healthy. No recovery needed."
        exit 0
    fi

    log_info "Problem detected. Attempting recovery: restarting service"
    systemctl restart "$SERVICE"
    
    log_info "Waiting $WAIT_TIME seconds before re-check"
    sleep "$WAIT_TIME"
    
    log_info "Re-checking service health after recovery..."
    if perform_all_checks; then
        log_info "Service successfully recovered."
        exit 0
    else
        log_error "Recovery failed, collecting diagnostics"
        diagnose
        exit 1
    fi
}

# ==========================================
# MAIN EXECUTION
# ==========================================
case "$MODE" in
    check)
        if perform_all_checks; then
            exit 0
        else
            exit 1
        fi
        ;;
    heal)
        heal
        ;;
    diagnose)
        log_info "Triggering diagnostics collection..."
        diagnose
        exit 1
        ;;
esac