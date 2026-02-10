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
# EFM AAP Failover Wrapper Script
# This script is called by EFM during database failover
#
# EFM passes the following parameters:
# $1 = cluster name
# $2 = node type (primary/standby/witness)
# $3 = node address
# $4 = VIP address (if configured)
#

set -e

CLUSTER_NAME="$1"
NODE_TYPE="$2"
NODE_ADDRESS="$3"
VIP_ADDRESS="${4:-}"

LOGFILE="/var/log/efm-aap-failover.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log_message() {
    echo "[$TIMESTAMP] $1" | tee -a "$LOGFILE"
}

log_message "========================================"
log_message "EFM AAP Failover Script Triggered"
log_message "========================================"
log_message "Cluster: $CLUSTER_NAME"
log_message "Node Type: $NODE_TYPE"
log_message "Node Address: $NODE_ADDRESS"
log_message "VIP Address: $VIP_ADDRESS"
log_message "========================================"

# Determine which datacenter this node is in based on address or hostname
DATACENTER=""
if [[ "$NODE_ADDRESS" == *"dc1"* ]] || [[ "$NODE_ADDRESS" == *"ocp1"* ]]; then
    DATACENTER="DC1"
    CLUSTER_CONTEXT="api-crc-testing:6443"
elif [[ "$NODE_ADDRESS" == *"dc2"* ]] || [[ "$NODE_ADDRESS" == *"ocp2"* ]]; then
    DATACENTER="DC2"
    CLUSTER_CONTEXT="api-chadsno2026-fteam-local:6443"
else
    log_message "ERROR: Unable to determine datacenter from node address"
    exit 1
fi

log_message "Detected Datacenter: $DATACENTER"
log_message "OpenShift Context: $CLUSTER_CONTEXT"

# Only scale up AAP if this node is being promoted to primary
if [ "$NODE_TYPE" = "standby" ]; then
    log_message "Node is being promoted to primary - scaling up AAP in $DATACENTER"
    
    # Check deployment type and call appropriate script
    if command -v oc &> /dev/null; then
        # OpenShift deployment
        log_message "Detected OpenShift deployment"
        /usr/edb/efm-4.x/bin/aap-failover.sh "$CLUSTER_CONTEXT"
        EXIT_CODE=$?
    else
        # RHEL deployment
        log_message "Detected RHEL deployment"
        /usr/edb/efm-4.x/bin/aap-failover.sh
        EXIT_CODE=$?
    fi
    
    if [ $EXIT_CODE -eq 0 ]; then
        log_message "✓ AAP cluster scaled up successfully in $DATACENTER"
    else
        log_message "✗ ERROR: Failed to scale up AAP cluster (exit code: $EXIT_CODE)"
        exit $EXIT_CODE
    fi
else
    log_message "Node type is $NODE_TYPE - no AAP scaling action required"
fi

log_message "EFM AAP Failover Script Completed"
log_message "========================================"

exit 0
