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
