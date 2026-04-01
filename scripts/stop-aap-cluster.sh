#!/bin/bash
# Stop AAP Cluster Services on RHEL
# This script stops all AAP components on a RHEL server
#

set -e

LOGFILE="/var/log/aap-shutdown.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log_message() {
    echo "[$TIMESTAMP] $1" | tee -a "$LOGFILE"
}

log_message "Stopping AAP cluster services..."

# Stop services in reverse order
AAP_SERVICES=(
    "nginx"
    "automation-hub"
    "automation-controller"
    "receptor"
    "redis"
    "postgresql"
)

for service in "${AAP_SERVICES[@]}"; do
    log_message "Stopping $service..."
    systemctl stop "$service" && log_message "✓ $service stopped" || log_message "✗ Failed to stop $service"
done

log_message "AAP cluster shutdown complete!"
