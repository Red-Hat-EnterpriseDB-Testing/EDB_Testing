# AAP Cluster Management Manual Scripts

This document contains the operational procedures and script code for managing AAP clusters in RHEL-based and OpenShift-based deployments.

[← Back to main README](../README.md#aap-cluster-management)

## Managing AAP on RHEL (systemctl)

For RHEL-based AAP deployments, AAP components run as systemd services. This approach is useful for traditional VM-based deployments or when running AAP outside of OpenShift.

### AAP Service Components on RHEL

The following systemd services are typically installed:

- `automation-controller.service` - AAP Controller service
- `automation-hub.service` - Automation Hub service (if installed)
- `receptor.service` - Receptor for job execution
- `nginx.service` - Web server/reverse proxy
- `redis.service` - Redis for caching and messaging
- `postgresql.service` - PostgreSQL database (if using local DB)

### Starting the Inactive AAP Cluster

Create a script to start all AAP services on the standby RHEL server:

**File**: `/usr/local/bin/start-aap-cluster.sh`

```bash
#!/bin/bash
#
# Start AAP Cluster Services
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
```

### Make the Script Executable

```bash
sudo chmod +x /usr/local/bin/start-aap-cluster.sh
```

### Create Systemd Service for AAP Cluster Startup

Create a systemd service to manage AAP cluster startup:

**File**: `/etc/systemd/system/aap-cluster.service`

```ini
[Unit]
Description=Ansible Automation Platform Cluster Services
After=network.target
Wants=postgresql.service redis.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/start-aap-cluster.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### Enable and Start the AAP Cluster Service

```bash
# Reload systemd to recognize new service
sudo systemctl daemon-reload

# Enable service to start on boot
sudo systemctl enable aap-cluster.service

# Start the AAP cluster manually
sudo systemctl start aap-cluster.service

# Check status
sudo systemctl status aap-cluster.service
```

### Stop AAP Cluster (for maintenance)

Create a companion script to stop services:

**File**: `/usr/local/bin/stop-aap-cluster.sh`

```bash
#!/bin/bash
#
# Stop AAP Cluster Services
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
```

```bash
sudo chmod +x /usr/local/bin/stop-aap-cluster.sh
```

### Manual Service Management

```bash
# Start individual services
sudo systemctl start automation-controller.service

# Stop individual services
sudo systemctl stop automation-controller.service

# Restart services
sudo systemctl restart automation-controller.service

# Check service status
sudo systemctl status automation-controller.service

# View service logs
sudo journalctl -u automation-controller.service -f

# Enable service on boot
sudo systemctl enable automation-controller.service

# Disable service on boot
sudo systemctl disable automation-controller.service
```

## Managing AAP on OpenShift (Pod Scaling)

For OpenShift-based AAP deployments, you can scale pods to zero to conserve resources in the standby datacenter, then scale them back up during failover or testing.

### Scaling AAP Pods to Zero

**Manual Scaling:**

```bash
# Set kubeconfig for the target cluster
export KUBECONFIG=~/.kube/kubeconfig

# Switch to AAP namespace
oc project ansible-automation-platform

# Scale AAP Controller to 0 replicas
oc scale deployment automation-controller-operator-controller-manager --replicas=0

# Scale Automation Hub to 0 replicas
oc scale deployment automation-hub-operator-controller-manager --replicas=0

# Scale AAP Gateway to 0 replicas
oc scale deployment aap-gateway --replicas=0

# Verify all pods are scaled down
oc get pods -n ansible-automation-platform
```

### Automated Scaling Script

Create a script to scale down all AAP components:

**File**: `scripts/scale-aap-down.sh`

```bash
#!/bin/bash
#
# Scale Down AAP Pods on OpenShift
# This script scales AAP components to zero replicas
#

set -e

# Configuration
NAMESPACE="ansible-automation-platform"
KUBECONFIG_FILE="${KUBECONFIG:-$HOME/.kube/config}"
CLUSTER_CONTEXT="${1:-api-changeme-local:6443}"

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
```

### Automated Scaling Up Script

Create a script to restore AAP components:

**File**: `scripts/scale-aap-up.sh`

```bash
#!/bin/bash
#
# Scale Up AAP Pods on OpenShift
# This script restores AAP components to operational replica counts
#

set -e

# Configuration
NAMESPACE="ansible-automation-platform"
KUBECONFIG_FILE="${KUBECONFIG:-$HOME/.kube/config}"
CLUSTER_CONTEXT="${1:-api-changeme:6443}"

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
```

### Make Scripts Executable

```bash
chmod +x scripts/scale-aap-down.sh
chmod +x scripts/scale-aap-up.sh
```

### Usage Examples

**Scale down AAP in DC2:**

```bash
# Using default context
./scripts/scale-aap-down.sh
```

**Scale up AAP in DC2:**

```bash
# Using default context
./scripts/scale-aap-up.sh
```

**Verify scaling operations:**

```bash
# Check current replica counts
oc get deployments -n ansible-automation-platform

# Watch pods scaling
watch oc get pods -n ansible-automation-platform

# Check AAP route
oc get route -n ansible-automation-platform

# Test AAP API accessibility
AAP_URL=$(oc get route -n ansible-automation-platform -o jsonpath='{.items[0].spec.host}')
curl -k https://$AAP_URL/api/v2/ping/
```

### Integration with Disaster Recovery

These scaling scripts can be integrated into disaster recovery procedures:

**Failover Scenario (DC1 → DC2):**

1. Detect DC1 failure
2. Scale up AAP pods in DC2: `./scripts/scale-aap-up.sh`
3. Promote DC2 database to read-write
4. Update global load balancer to route to DC2
5. Verify AAP is accepting connections

**Failback Scenario (DC2 → DC1):**

1. Ensure DC1 is fully recovered
2. Synchronize database from DC2 to DC1
3. Scale up AAP pods in DC1: `./scripts/scale-aap-up.sh api-crc-testing:6443`
4. Update global load balancer to route to DC1
5. Scale down AAP pods in DC2: `./scripts/scale-aap-down.sh`

### Monitoring and Alerting

Add monitoring for scaled-down clusters:

```bash
# Check if AAP is scaled down
SCALED_DOWN=$(oc get deployments -n ansible-automation-platform -o json | \
    jq '[.items[] | select(.metadata.name | contains("automation")) | .spec.replicas] | add')

if [ "$SCALED_DOWN" -eq 0 ]; then
    echo "AAP is in standby mode (scaled to zero)"
else
    echo "AAP is active with $SCALED_DOWN total replicas"
fi
```

## Integration with AAP Workflows

The Ansible playbooks can be integrated into AAP Workflow Templates for complete automation:

**Workflow Example: Complete DR Failover**

1. **Check Source DC Status**
   - Job Template: Check Health
   - Playbook: `check-health.yml`
   - On Failure: Continue to failover

2. **Execute Failover**
   - Job Template: DR Failover
   - Playbook: `disaster-recovery-failover.yml`
   - Extra Vars: `{ failover_source_dc: "dc1", failover_target_dc: "dc2" }`

3. **Verify Target DC Health**
   - Job Template: Verify Health
   - Playbook: `check-health.yml`
   - On Failure: Alert and rollback

4. **Update Monitoring**
   - Job Template: Update Monitoring
   - Custom playbook for your monitoring system

5. **Send Notifications**
   - Job Template: Notify Stakeholders
   - Email/Slack/PagerDuty notifications

### Testing Ansible Automation

```bash
# Test in check mode (no changes)
ansible-playbook edb.postgres_operations.disaster-recovery-failover \
  -e 'failover_source_dc=dc1' \
  -e 'failover_target_dc=dc2' \
  --check

# Test with increased verbosity
ansible-playbook edb.postgres_operations.manage-aap-cluster \
  -e 'manage_aap_cluster_action=status' \
  -vvv

# Test specific tags
ansible-playbook edb.postgres_operations.setup-efm-integration \
  -i inventory \
  -l efm_nodes \
  --tags test
```
or OpenShift-based AAP deployments, you can scale pods to zero to conserve resources in the standby datacenter, then scale them back up during failover or testing.

#### Scaling AAP Pods to Zero

**Manual Scaling:**

```bash
# Set kubeconfig for the target cluster
export KUBECONFIG=~/.kube/kubeconfig

# Switch to AAP namespace
oc project ansible-automation-platform

# Scale AAP Controller to 0 replicas
oc scale deployment automation-controller-operator-controller-manager --replicas=0

# Scale Automation Hub to 0 replicas
oc scale deployment automation-hub-operator-controller-manager --replicas=0

# Scale AAP Gateway to 0 replicas
oc scale deployment aap-gateway --replicas=0

# Verify all pods are scaled down
oc get pods -n ansible-automation-platform
```

#### Automated Scaling Script

Create a script to scale down all AAP components:

**File**: `scripts/scale-aap-down.sh`

```bash
#!/bin/bash
#
# Scale Down AAP Pods on OpenShift
# This script scales AAP components to zero replicas
#

set -e

# Configuration
NAMESPACE="ansible-automation-platform"
KUBECONFIG_FILE="${KUBECONFIG:-$HOME/.kube/config}"
CLUSTER_CONTEXT="${1:-api-changeme-local:6443}"

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
```

#### Automated Scaling Up Script

Create a script to restore AAP components:

**File**: `scripts/scale-aap-up.sh`

```bash
#!/bin/bash
#
# Scale Up AAP Pods on OpenShift
# This script restores AAP components to operational replica counts
#

set -e

# Configuration
NAMESPACE="ansible-automation-platform"
KUBECONFIG_FILE="${KUBECONFIG:-$HOME/.kube/config}"
CLUSTER_CONTEXT="${1:-api-changeme:6443}"

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
```

#### Make Scripts Executable

```bash
chmod +x scripts/scale-aap-down.sh
chmod +x scripts/scale-aap-up.sh
```

#### Usage Examples

**Scale down AAP in DC2:**

```bash
# Using default context
./scripts/scale-aap-down.sh
```

**Scale up AAP in DC2:**

```bash
# Using default context
./scripts/scale-aap-up.sh
```

**Verify scaling operations:**

```bash
# Check current replica counts
oc get deployments -n ansible-automation-platform

# Watch pods scaling
watch oc get pods -n ansible-automation-platform

# Check AAP route
oc get route -n ansible-automation-platform

# Test AAP API accessibility
AAP_URL=$(oc get route -n ansible-automation-platform -o jsonpath='{.items[0].spec.host}')
curl -k https://$AAP_URL/api/v2/ping/
```

#### Integration with Disaster Recovery

These scaling scripts can be integrated into disaster recovery procedures:

**Failover Scenario (DC1 → DC2):**

1. Detect DC1 failure
2. Scale up AAP pods in DC2: `./scripts/scale-aap-up.sh`
3. Promote DC2 database to read-write
4. Update global load balancer to route to DC2
5. Verify AAP is accepting connections

**Failback Scenario (DC2 → DC1):**

1. Ensure DC1 is fully recovered
2. Synchronize database from DC2 to DC1
3. Scale up AAP pods in DC1: `./scripts/scale-aap-up.sh api-crc-testing:6443`
4. Update global load balancer to route to DC1
5. Scale down AAP pods in DC2: `./scripts/scale-aap-down.sh`

#### Monitoring and Alerting

Add monitoring for scaled-down clusters:

```bash
# Check if AAP is scaled down
SCALED_DOWN=$(oc get deployments -n ansible-automation-platform -o json | \
    jq '[.items[] | select(.metadata.name | contains("automation")) | .spec.replicas] | add')

if [ "$SCALED_DOWN" -eq 0 ]; then
    echo "AAP is in standby mode (scaled to zero)"
else
    echo "AAP is active with $SCALED_DOWN total replicas"
fi
```
