#!/bin/bash
# Scale Up AAP Pods on OpenShift
# This script restores AAP components to operational replica counts
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
DB_NAMESPACE="edb-postgres"
DB_CLUSTER="postgresql"
KUBECONFIG_FILE="${KUBECONFIG:-$HOME/.kube/config}"

# Default cluster context - update to your cluster context from your kubeconfig file.
# Run 'kubectl config get-contexts' to list available contexts. Pass context as $1 to override.
# Or set via environment variable: export CLUSTER_CONTEXT=<your-context>
DEFAULT_CLUSTER_CONTEXT="${CLUSTER_CONTEXT:-your-cluster-context}"
CLUSTER_CONTEXT="${1:-$DEFAULT_CLUSTER_CONTEXT}"

# Setup logging
setup_logging "scale-aap-up"

log_section "AAP Scale Up Script"
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

# CRITICAL: Verify database is in PRIMARY mode to prevent split-brain
log ""
if ! validate_database_primary "$DB_NAMESPACE" "$DB_CLUSTER"; then
    exit 1
fi
log ""

log "Scaling up AAP deployments..."
log ""

# Scale each deployment to target replicas (using shared function with idempotency)
SCALED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0

for deployment in "${!AAP_DEPLOYMENTS[@]}"; do
    replicas="${AAP_DEPLOYMENTS[$deployment]}"

    if scale_deployment "$deployment" "$NAMESPACE" "$replicas"; then
        current=$(get_current_replicas "$deployment" "$NAMESPACE")
        if [ "$current" -ne "$replicas" ]; then
            SCALED_COUNT=$((SCALED_COUNT + 1))
        else
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        fi
    else
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
done

log ""
log "Scaling summary: $SCALED_COUNT scaled, $SKIPPED_COUNT already at target, $FAILED_COUNT failed"

if [ $FAILED_COUNT -gt 0 ]; then
    log_warn "Some deployments failed to scale"
fi

# Wait for pods to be ready
log ""
if wait_for_pods "$NAMESPACE" 10 300; then
    log_success "AAP pods are ready"
else
    log_warn "Some pods may not be ready yet"
fi

log ""
log "Current pod status:"
oc get pods -n "$NAMESPACE" 2>/dev/null | grep -E 'NAME|^(automation-(controller|hub)|aap-gateway)' || true

log ""
log_section "Scale Up Operation Complete"

# Get AAP route
AAP_ROUTE=$(oc get route -n "$NAMESPACE" -o jsonpath='{.items[0].spec.host}' 2>/dev/null || echo "route-not-found")
log "AAP URL: https://$AAP_ROUTE"
log ""
log "Log file: $LOG_FILE"
