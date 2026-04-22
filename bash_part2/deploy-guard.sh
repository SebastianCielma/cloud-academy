#!/bin/bash

log_info() { echo "[INFO] $1"; }
log_warn() { echo "[WARNING] $1"; }
log_error() { echo "[ERROR] $1"; }

SERVICE=""
VERSION=""
HEALTH_URL=""
DELAY=""


while [[ "$#" -gt 0 ]]; do
    case $1 in
        --service) SERVICE="$2"; shift ;;
        --version) VERSION="$2"; shift ;;
        --health-url) HEALTH_URL="$2"; shift ;;
        --delay) DELAY="$2"; shift ;;
        *) 
            log_error "Unknown parameter: $1"
            exit 2 
            ;;
    esac
    shift
done

if [[ -z "$SERVICE" || -z "$VERSION" || -z "$HEALTH_URL" || -z "$DELAY" ]]; then
    log_error "Missing arguments."
    log_info "Example: ./deploy-guard.sh --service payment-api --version v2 --health-url http://localhost:8080/health --delay 5"
    exit 2
fi

# ==========================================
#  STATE TRACKING & SERVICE START
# ==========================================
PREVIOUS_VERSION=$(cat state/instance-1 2>/dev/null || echo "v1")

log_info "Starting deployment for $SERVICE version $VERSION"
log_info "Current version (rollback target) is: $PREVIOUS_VERSION"

log_info "Starting service process for version: $VERSION"
bash start_service.sh "$VERSION"

sleep 2 

# ==========================================
# PROGRESSIVE ROLLOUT & VALIDATION
# ==========================================
for INSTANCE_ID in 1 2 3; do
    INSTANCE_NAME="instance-$INSTANCE_ID"
    
    log_info "Deploying to $INSTANCE_NAME"
    echo "$VERSION" > "state/$INSTANCE_NAME"
    
    log_info "Waiting $DELAY seconds"
    sleep "$DELAY"
    
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL")
    
    if [[ "$HTTP_STATUS" == "200" ]]; then
        log_info "Health check passed"
    else
        # ==========================================
        # ROLLBACK MECHANISM
        # ==========================================
        log_error "Health check failed (HTTP Status: $HTTP_STATUS)"
        log_warn "Rolling back deployment"
        
        log_info "Reverting service process to $PREVIOUS_VERSION..."
        bash start_service.sh "$PREVIOUS_VERSION"
        sleep 2
        
        for ROLLBACK_ID in 1 2 3; do
            echo "$PREVIOUS_VERSION" > "state/instance-$ROLLBACK_ID"
        done
        
        log_info "Rollback successful"
        exit 1 
    fi
done

# ==========================================
# SUCCESS
# ==========================================
log_info "Deployment successful! All instances updated to $VERSION."
exit 0 