#!/bin/bash
# Shared AAP Scaling Library
# Common functions for scaling AAP deployments
#

# AAP deployment definitions with operational replica counts
declare -gA AAP_DEPLOYMENTS=(
    ["aap-gateway"]="3"
    ["automation-controller-operator-controller-manager"]="1"
    ["automation-controller-task"]="3"
    ["automation-controller-web"]="3"
    ["automation-hub-operator-controller-manager"]="1"
    ["automation-hub-api"]="2"
    ["automation-hub-content"]="2"
    ["automation-hub-worker"]="2"
)

# Validate cluster context is not a placeholder
# Usage: validate_cluster_context <context>
validate_cluster_context() {
    local context="$1"

    if [[ -z "$context" ]]; then
        echo "ERROR: Cluster context is empty" >&2
        return 1
    fi

    if [[ "$context" == *"your-"* ]] || [[ "$context" == *"example"* ]]; then
        echo "ERROR: Cluster context contains placeholder value: $context" >&2
        echo "Please provide a valid cluster context:" >&2
        echo "  - Set as script argument: $0 <cluster-context>" >&2
        echo "  - Set environment variable: export CLUSTER_CONTEXT=<context>" >&2
        echo "  - Update script default value" >&2
        echo "" >&2
        echo "Available contexts:" >&2
        oc config get-contexts -o name 2>/dev/null || kubectl config get-contexts -o name 2>/dev/null || true
        return 1
    fi

    return 0
}

# Get current replica count for a deployment
# Usage: get_current_replicas <deployment> <namespace>
get_current_replicas() {
    local deployment="$1"
    local namespace="$2"

    oc get deployment "$deployment" -n "$namespace" \
        -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0"
}

# Check if deployment needs scaling
# Usage: needs_scaling <deployment> <namespace> <target-replicas>
# Returns: 0 if scaling needed, 1 if already at target
needs_scaling() {
    local deployment="$1"
    local namespace="$2"
    local target="$3"

    local current
    current=$(get_current_replicas "$deployment" "$namespace")

    if [ "$current" -eq "$target" ]; then
        return 1  # No scaling needed
    else
        return 0  # Scaling needed
    fi
}

# Validate database is in primary mode (split-brain prevention)
# Usage: validate_database_primary <db-namespace> <db-cluster>
validate_database_primary() {
    local db_namespace="$1"
    local db_cluster="$2"

    echo "Validating database role (split-brain prevention)..."

    # Get the primary database pod
    local db_pod
    db_pod=$(oc get pods -n "$db_namespace" \
        -l "cnpg.io/cluster=$db_cluster,role=primary" \
        -o name 2>/dev/null | head -1)

    if [ -z "$db_pod" ]; then
        echo "❌ ERROR: Cannot find primary database pod in namespace $db_namespace" >&2
        echo "This may indicate:" >&2
        echo "  1. Database cluster is down" >&2
        echo "  2. No primary exists (cluster in replica-only mode)" >&2
        echo "  3. Namespace or cluster name is incorrect" >&2
        echo "" >&2
        echo "DO NOT scale AAP when database is not in PRIMARY mode!" >&2
        return 1
    fi

    # Verify the database is not in recovery (not a replica)
    echo "Checking database pod: $db_pod"
    local in_recovery
    in_recovery=$(oc exec -n "$db_namespace" "$db_pod" -- \
        psql -U postgres -t -c "SELECT pg_is_in_recovery();" 2>/dev/null | tr -d '[:space:]')

    if [ "$in_recovery" = "t" ]; then
        echo "❌ CRITICAL ERROR: Database is in RECOVERY mode (acting as a REPLICA)" >&2
        echo "" >&2
        echo "This means the database is currently a standby/replica, NOT a primary." >&2
        echo "Scaling AAP pods against a replica database will cause:" >&2
        echo "  - Connection failures (replicas are read-only)" >&2
        echo "  - Data integrity issues" >&2
        echo "  - Split-brain scenario if primary still exists elsewhere" >&2
        echo "" >&2
        echo "ACTION REQUIRED:" >&2
        echo "  1. Verify this is the correct datacenter/cluster" >&2
        echo "  2. If failover is needed, promote this replica to primary first" >&2
        echo "  3. Then re-run this script" >&2
        echo "" >&2
        return 1
    elif [ "$in_recovery" = "f" ]; then
        echo "✅ Database is in PRIMARY mode - safe to scale AAP"
        return 0
    else
        echo "⚠ WARNING: Could not determine database recovery status" >&2
        echo "Response: '$in_recovery'" >&2
        echo "Proceeding with caution..." >&2
        return 0
    fi
}

# Wait for pods to reach desired state
# Usage: wait_for_pods <namespace> <min-ready-count> <timeout>
wait_for_pods() {
    local namespace="$1"
    local min_ready="${2:-10}"
    local timeout="${3:-300}"

    echo "Waiting for pods to be ready (min: $min_ready, timeout: ${timeout}s)..."

    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        # Count ready pods (more specific pattern matching)
        local ready_pods
        ready_pods=$(oc get pods -n "$namespace" \
            --field-selector=status.phase=Running \
            --no-headers 2>/dev/null | \
            grep -E '^(automation-(controller|hub)|aap-gateway)' | \
            grep -E '\s(1/1|2/2|3/3)\s' | \
            wc -l || echo 0)

        local total_pods
        total_pods=$(oc get pods -n "$namespace" \
            --field-selector=status.phase=Running \
            --no-headers 2>/dev/null | \
            grep -E '^(automation-(controller|hub)|aap-gateway)' | \
            wc -l || echo 0)

        echo "  Ready pods: $ready_pods / $total_pods (elapsed: ${elapsed}s)"

        if [ "$ready_pods" -ge "$min_ready" ]; then
            echo "✅ Pods are ready!"
            return 0
        fi

        sleep 10
        elapsed=$((elapsed + 10))
    done

    echo "⚠ WARNING: Timeout waiting for pods (${timeout}s)" >&2
    return 1
}

# Scale AAP deployment with idempotency check
# Usage: scale_deployment <deployment> <namespace> <target-replicas>
scale_deployment() {
    local deployment="$1"
    local namespace="$2"
    local target="$3"

    # Check if deployment exists
    if ! oc get deployment "$deployment" -n "$namespace" &>/dev/null; then
        echo "⚠ Deployment $deployment not found, skipping..."
        return 0
    fi

    # Check if scaling is needed (idempotency)
    local current
    current=$(get_current_replicas "$deployment" "$namespace")

    if [ "$current" -eq "$target" ]; then
        echo "✓ $deployment already at $target replicas (skipping)"
        return 0
    fi

    # Perform scaling
    echo "Scaling: $deployment from $current to $target replicas"
    if oc scale deployment "$deployment" -n "$namespace" --replicas="$target" 2>/dev/null; then
        echo "✓ $deployment scaled to $target replicas"
        return 0
    else
        echo "❌ Failed to scale $deployment" >&2
        return 1
    fi
}
