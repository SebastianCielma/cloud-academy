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
            log_error "Error: $1"
            exit 2 
            ;;
    esac
    shift
done

if [[ -z "$SERVICE" || -z "$VERSION" || -z "$HEALTH_URL" || -z "$DELAY" ]]; then
    log_error "Error"
    exit 2 
fi

log_info "Starting deployment for $SERVICE version $VERSION" [cite: 82]