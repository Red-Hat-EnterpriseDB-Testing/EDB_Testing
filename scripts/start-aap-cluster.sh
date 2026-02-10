#!/bin/bash
#
# Start AAP Cluster Services on RHEL
# This script starts all AAP components on a standby RHEL server
#

set -e

LOGFILE="/var/log/aap-startup.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log_message() {
    echo "[$TIMESTAMP] $1" | tee -a "$LOGFILE"
}

log_message "Starting AAP cluster services..."

# Array of services to start in order
AAP_SERVICES=(
    "postgresql"
    "redis"
    "receptor"
    "automation-controller"
    "automation-hub"
    "nginx"
)

# Start each service and verify it's running
for service in "${AAP_SERVICES[@]}"; do
    log_message "Starting $service..."
    
    if systemctl start "$service"; then
        log_message "✓ $service started successfully"
        
        # Wait for service to be fully ready
        sleep 5
        
        if systemctl is-active --quiet "$service"; then
            log_message "✓ $service is active and running"
        else
            log_message "✗ Warning: $service may not be fully ready"
        fi
    else
        log_message "✗ Failed to start $service"
        exit 1
    fi
done

# Verify AAP Controller is responding
log_message "Verifying AAP Controller API..."
sleep 10

if curl -k -s -o /dev/null -w "%{http_code}" https://localhost/api/v2/ping/ | grep -q "200"; then
    log_message "✓ AAP Controller API is responding"
else
    log_message "✗ Warning: AAP Controller API not responding yet"
fi

log_message "AAP cluster startup complete!"
log_message "Access AAP at: https://$(hostname)/api/v2/"
