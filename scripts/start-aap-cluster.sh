#!/bin/bash
#
# Copyright 2026 EnterpriseDB Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
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
