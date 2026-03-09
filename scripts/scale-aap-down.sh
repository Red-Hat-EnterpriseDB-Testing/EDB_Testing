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
# Scale Down AAP Pods on OpenShift
# This script scales AAP components to zero replicas
#

set -e

# Configuration
NAMESPACE="ansible-automation-platform"
KUBECONFIG_FILE="${KUBECONFIG:-$HOME/.kube/config}"
# Default cluster context - update to your cluster context from your kubeconfig file.
# Run 'kubectl config get-contexts' to list available contexts. Pass context as $1 to override.
DEFAULT_CLUSTER_CONTEXT="your-cluster-context"
CLUSTER_CONTEXT="${1:-$DEFAULT_CLUSTER_CONTEXT}"

echo "==================================="
echo "AAP Scale Down Script"
echo "==================================="
echo "Namespace: $NAMESPACE"
echo "Context: $CLUSTER_CONTEXT"
echo "==================================="

# Set kubeconfig
export KUBECONFIG="$KUBECONFIG_FILE"

# Switch to target context
echo "Switching to context: $CLUSTER_CONTEXT"
oc config use-context "$CLUSTER_CONTEXT" || {
    echo "Error: Failed to switch context"
    exit 1
}

# Verify current context
CURRENT_CONTEXT=$(oc config current-context)
echo "Current context: $CURRENT_CONTEXT"

# Switch to AAP namespace
echo "Switching to namespace: $NAMESPACE"
oc project "$NAMESPACE" || {
    echo "Error: Namespace $NAMESPACE not found"
    exit 1
}

# Define AAP deployments to scale down
AAP_DEPLOYMENTS=(
    "aap-gateway"
    "automation-controller-operator-controller-manager"
    "automation-controller-task"
    "automation-controller-web"
    "automation-hub-operator-controller-manager"
    "automation-hub-api"
    "automation-hub-content"
    "automation-hub-worker"
)

echo ""
echo "Scaling down AAP deployments..."
echo ""

# Scale each deployment to 0
for deployment in "${AAP_DEPLOYMENTS[@]}"; do
    if oc get deployment "$deployment" -n "$NAMESPACE" &>/dev/null; then
        echo "Scaling down: $deployment"
        oc scale deployment "$deployment" -n "$NAMESPACE" --replicas=0
        echo "✓ $deployment scaled to 0 replicas"
    else
        echo "⚠ Deployment $deployment not found, skipping..."
    fi
done

echo ""
echo "Waiting for pods to terminate..."
sleep 10

# Verify pods are scaled down
REMAINING_PODS=$(oc get pods -n "$NAMESPACE" --field-selector=status.phase=Running --no-headers 2>/dev/null | grep -E "automation|aap-gateway" | wc -l || echo 0)

if [ "$REMAINING_PODS" -eq 0 ]; then
    echo "✓ All AAP pods have been scaled down successfully"
else
    echo "⚠ Warning: $REMAINING_PODS AAP pods still running"
    echo "Remaining pods:"
    oc get pods -n "$NAMESPACE" --field-selector=status.phase=Running | grep -E "automation|aap-gateway" || true
fi

echo ""
echo "Scale down operation complete!"
echo "Database pods are NOT scaled down (intentional for replication)"
