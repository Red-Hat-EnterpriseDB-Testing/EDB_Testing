#!/bin/bash
# EFM AAP Failover Wrapper Script
# This script is called by EFM during database failover
#
# EFM passes the following parameters:
# $1 = cluster name
# $2 = node type (primary/standby/witness)
# $3 = node address
# $4 = VIP address (if configured)
#

set -euo pipefail

CLUSTER_NAME="$1"
NODE_TYPE="$2"
NODE_ADDRESS="$3"
VIP_ADDRESS="${4:-}"

# Cluster contexts for OpenShift - update these to your cluster context from your kubeconfig file.
# Run 'kubectl config get-contexts' to list available contexts.
DC1_CLUSTER_CONTEXT="${DC1_CLUSTER_CONTEXT:-your-dc1-cluster-context}"
DC2_CLUSTER_CONTEXT="${DC2_CLUSTER_CONTEXT:-your-dc2-cluster-context}"

# Validate configuration is not using placeholder values
if [[ "$DC1_CLUSTER_CONTEXT" == *"your-"* ]] || [[ "$DC1_CLUSTER_CONTEXT" == *"example"* ]]; then
    echo "ERROR: DC1_CLUSTER_CONTEXT contains placeholder value: $DC1_CLUSTER_CONTEXT" >&2
    echo "Please set DC1_CLUSTER_CONTEXT environment variable or update this script" >&2
    exit 1
fi

if [[ "$DC2_CLUSTER_CONTEXT" == *"your-"* ]] || [[ "$DC2_CLUSTER_CONTEXT" == *"example"* ]]; then
    echo "ERROR: DC2_CLUSTER_CONTEXT contains placeholder value: $DC2_CLUSTER_CONTEXT" >&2
    echo "Please set DC2_CLUSTER_CONTEXT environment variable or update this script" >&2
    exit 1
fi

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
# Uses strict pattern matching to avoid false positives
DATACENTER=""
CLUSTER_CONTEXT=""

case "$NODE_ADDRESS" in
    # DC1 patterns: exact domain matches and IP ranges
    *.dc1.* | *-dc1-* | 10.1.*.* | *.ocp1.* | *-ocp1-*)
        DATACENTER="DC1"
        CLUSTER_CONTEXT="$DC1_CLUSTER_CONTEXT"
        ;;
    # DC2 patterns: exact domain matches and IP ranges
    *.dc2.* | *-dc2-* | 10.2.*.* | *.ocp2.* | *-ocp2-*)
        DATACENTER="DC2"
        CLUSTER_CONTEXT="$DC2_CLUSTER_CONTEXT"
        ;;
    *)
        log_message "ERROR: Unable to determine datacenter from node address: $NODE_ADDRESS"
        log_message "Expected patterns:"
        log_message "  DC1: *.dc1.*, *-dc1-*, 10.1.*.*, *.ocp1.*, *-ocp1-*"
        log_message "  DC2: *.dc2.*, *-dc2-*, 10.2.*.*, *.ocp2.*, *-ocp2-*"
        log_message "Please update the pattern matching in this script to match your environment"
        exit 1
        ;;
esac

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
