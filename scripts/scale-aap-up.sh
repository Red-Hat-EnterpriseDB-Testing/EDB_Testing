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
# Scale Up AAP Pods on OpenShift
# This script restores AAP components to operational replica counts
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
echo "AAP Scale Up Script"
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

# Define AAP deployments with target replica counts
# Format: "deployment:replicas"
declare -A AAP_DEPLOYMENTS=(
    ["aap-gateway"]="3"
    ["automation-controller-operator-controller-manager"]="1"
    ["automation-controller-task"]="3"
    ["automation-controller-web"]="3"
    ["automation-hub-operator-controller-manager"]="1"
    ["automation-hub-api"]="2"
    ["automation-hub-content"]="2"
    ["automation-hub-worker"]="2"
)

echo ""
echo "Scaling up AAP deployments..."
echo ""

# Scale each deployment to target replicas
for deployment in "${!AAP_DEPLOYMENTS[@]}"; do
    replicas="${AAP_DEPLOYMENTS[$deployment]}"
    
    if oc get deployment "$deployment" -n "$NAMESPACE" &>/dev/null; then
        echo "Scaling up: $deployment to $replicas replicas"
        oc scale deployment "$deployment" -n "$NAMESPACE" --replicas="$replicas"
        echo "✓ $deployment scaled to $replicas replicas"
    else
        echo "⚠ Deployment $deployment not found, skipping..."
    fi
done

echo ""
echo "Waiting for pods to start..."
sleep 15

# Wait for pods to be ready
echo "Checking pod readiness..."
MAX_WAIT=300
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
    READY_PODS=$(oc get pods -n "$NAMESPACE" --field-selector=status.phase=Running --no-headers 2>/dev/null | grep -E "automation|aap-gateway" | grep "1/1\|2/2\|3/3" | wc -l || echo 0)
    TOTAL_PODS=$(oc get pods -n "$NAMESPACE" --field-selector=status.phase=Running --no-headers 2>/dev/null | grep -E "automation|aap-gateway" | wc -l || echo 0)
    
    echo "Ready pods: $READY_PODS / $TOTAL_PODS"
    
    if [ "$READY_PODS" -ge 10 ]; then
        echo "✓ AAP pods are ready!"
        break
    fi
    
    sleep 10
    ELAPSED=$((ELAPSED + 10))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    echo "⚠ Warning: Timeout waiting for pods to be ready"
fi

echo ""
echo "Current pod status:"
oc get pods -n "$NAMESPACE" | grep -E "NAME|automation|aap-gateway"

echo ""
echo "Scale up operation complete!"
echo ""
echo "Verify AAP is accessible:"
AAP_ROUTE=$(oc get route -n "$NAMESPACE" -o jsonpath='{.items[0].spec.host}' 2>/dev/null || echo "route-not-found")
echo "AAP URL: https://$AAP_ROUTE"
