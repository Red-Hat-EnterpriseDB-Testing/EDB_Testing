#!/bin/bash
# Scale Down AAP Pods on OpenShift
# This script scales AAP components to zero replicas
#

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared libraries
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/logging.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/aap-scaling.sh"

# Configuration
NAMESPACE="ansible-automation-platform"
KUBECONFIG_FILE="${KUBECONFIG:-$HOME/.kube/config}"

# Default cluster context - update to your cluster context from your kubeconfig file.
# Run 'kubectl config get-contexts' to list available contexts. Pass context as $1 to override.
# Or set via environment variable: export CLUSTER_CONTEXT=<your-context>
DEFAULT_CLUSTER_CONTEXT="${CLUSTER_CONTEXT:-your-cluster-context}"
CLUSTER_CONTEXT="${1:-$DEFAULT_CLUSTER_CONTEXT}"

# Setup logging
setup_logging "scale-aap-down"

log_section "AAP Scale Down Script"
log "Namespace: $NAMESPACE"
log "Context: $CLUSTER_CONTEXT"
log "Log file: $LOG_FILE"
log_raw "==================================="
log ""

# Validate cluster context
if ! validate_cluster_context "$CLUSTER_CONTEXT"; then
    exit 1
fi

# Set kubeconfig
export KUBECONFIG="$KUBECONFIG_FILE"

# Switch to target context
log "Switching to context: $CLUSTER_CONTEXT"
if oc config use-context "$CLUSTER_CONTEXT" >> "$LOG_FILE" 2>&1; then
    log_success "Context switched successfully"
else
    log_failure "Failed to switch context"
    exit 1
fi

# Verify current context
CURRENT_CONTEXT=$(oc config current-context)
log "Current context: $CURRENT_CONTEXT"

# Switch to AAP namespace
log "Switching to namespace: $NAMESPACE"
if oc project "$NAMESPACE" >> "$LOG_FILE" 2>&1; then
    log_success "Namespace set successfully"
else
    log_failure "Namespace $NAMESPACE not found"
    exit 1
fi

log ""
log "Scaling down AAP deployments to 0 replicas..."
log ""

# Scale each deployment to 0 (using shared function with idempotency)
SCALED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0

for deployment in "${!AAP_DEPLOYMENTS[@]}"; do
    if scale_deployment "$deployment" "$NAMESPACE" 0; then
        current=$(get_current_replicas "$deployment" "$NAMESPACE")
        if [ "$current" -ne 0 ]; then
            SCALED_COUNT=$((SCALED_COUNT + 1))
        else
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        fi
    else
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
done

log ""
log "Scaling summary: $SCALED_COUNT scaled down, $SKIPPED_COUNT already at 0, $FAILED_COUNT failed"

if [ $FAILED_COUNT -gt 0 ]; then
    log_warn "Some deployments failed to scale down"
fi

log ""
log "Waiting for pods to terminate..."
sleep 10

# Verify pods are scaled down (use more specific pattern)
REMAINING_PODS=$(oc get pods -n "$NAMESPACE" \
    --field-selector=status.phase=Running \
    --no-headers 2>/dev/null | \
    grep -E '^(automation-(controller|hub)|aap-gateway)' | \
    wc -l || echo 0)

log ""
if [ "$REMAINING_PODS" -eq 0 ]; then
    log_success "All AAP pods have been scaled down successfully"
else
    log_warn "$REMAINING_PODS AAP pods still running"
    log "Remaining pods:"
    oc get pods -n "$NAMESPACE" --field-selector=status.phase=Running 2>/dev/null | \
        grep -E 'NAME|^(automation-(controller|hub)|aap-gateway)' || true
fi

log ""
log_section "Scale Down Operation Complete"
log "Note: Database pods are NOT scaled down (intentional for replication)"
log "Log file: $LOG_FILE"
