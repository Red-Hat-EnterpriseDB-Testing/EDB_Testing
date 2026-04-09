# EDB EFM (Enterprise Failover Manager) Integration

EDB Failover Manager (EFM) can automatically trigger the Ansible Automation Platform (AAP) cluster management scripts during PostgreSQL database failover events. This provides seamless coordination between database failover and AAP cluster activation.

[← Back to main README](../README.md#aap-cluster-management)

## EFM Overview

EFM monitors PostgreSQL database clusters and automatically promotes standby nodes to primary when failures are detected. During this process, EFM can execute custom scripts at specific points in the failover lifecycle:

- **Pre-promotion**: Before promoting a standby database
- **Post-promotion**: After successfully promoting a standby to primary
- **Post-failure**: After detecting primary database failure
- **Pre-resume**: Before resuming monitoring after manual intervention

## EFM Script Locations

EFM scripts are typically located in:

```bash
# Default EFM script directory
/etc/edb/efm-4.x/

# Custom scripts directory (configurable)
/usr/edb/efm-4.x/bin/
```

## Integration Architecture

When EFM detects a database failure and promotes the standby:

1. **Pre-Promotion Hook**: EFM detects primary failure
2. **Post-Promotion Hook**: EFM promotes standby to primary
3. **Custom Script Execution**: EFM calls AAP scale-up script
4. **AAP Activation**: AAP cluster becomes active in DR datacenter
5. **Service Restoration**: Applications reconnect to new primary and active AAP

## Installing Scripts for EFM Integration

### Step 1: Copy Scripts to EFM Directory

```bash
# For OpenShift-based AAP deployments
sudo cp scripts/scale-aap-up.sh /usr/edb/efm-4.x/bin/aap-failover.sh
sudo cp scripts/scale-aap-down.sh /usr/edb/efm-4.x/bin/aap-failback.sh
sudo chmod +x /usr/edb/efm-4.x/bin/aap-failover.sh
sudo chmod +x /usr/edb/efm-4.x/bin/aap-failback.sh

# For RHEL-based AAP deployments
sudo cp scripts/start-aap-cluster.sh /usr/edb/efm-4.x/bin/aap-failover.sh
sudo cp scripts/stop-aap-cluster.sh /usr/edb/efm-4.x/bin/aap-failback.sh
sudo chmod +x /usr/edb/efm-4.x/bin/aap-failover.sh
sudo chmod +x /usr/edb/efm-4.x/bin/aap-failback.sh
```

### Step 2: Create EFM Wrapper Script

EFM passes specific parameters to custom scripts. Create a wrapper to handle these:

**File**: `/usr/edb/efm-4.x/bin/efm-aap-failover-wrapper.sh`

```bash
#!/bin/bash
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
    CLUSTER_CONTEXT="api-changeme:6443"
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
```

### Step 3: Make Wrapper Executable

```bash
sudo chmod +x /usr/edb/efm-4.x/bin/efm-aap-failover-wrapper.sh
sudo chown efm:efm /usr/edb/efm-4.x/bin/efm-aap-failover-wrapper.sh
```

## Configuring EFM to Call Custom Scripts

Edit the EFM configuration file for your cluster:

**File**: `/etc/edb/efm-4.x/efm.properties`

```ini
# Post-Promotion Script (runs on newly promoted primary)
# This script activates AAP in the datacenter where database was promoted
script.post.promotion=/usr/edb/efm-4.x/bin/efm-aap-failover-wrapper.sh %h %s %a %v

# Post-Failure Script (runs after detecting primary failure)
# Optional: Use for additional logging or alerting
script.post.failure=/usr/edb/efm-4.x/bin/efm-failure-notification.sh %h %s %a %v

# Script Timeout (seconds)
# Allow sufficient time for AAP to start (300 seconds = 5 minutes)
script.timeout=300

# Enable script execution
enable.custom.scripts=true
```

**EFM Script Parameters:**

- `%h` - Cluster name
- `%s` - Node type (primary/standby/witness)
- `%a` - Node address
- `%v` - Virtual IP address (if configured)

### Step 4: Restart EFM to Apply Changes

```bash
# Restart EFM service
sudo systemctl restart edb-efm-4.x

# Verify EFM is running
sudo systemctl status edb-efm-4.x

# Check EFM logs
sudo tail -f /var/log/efm-4.x/efm-startup.log
```

## Testing EFM Integration

Before relying on automatic failover, test the integration:

### Test 1: Manual Script Execution

```bash
# Test the wrapper script directly (simulate EFM call)
sudo /usr/edb/efm-4.x/bin/efm-aap-failover-wrapper.sh \
    "prod-db" \
    "standby" \
    "prod-db-replica-dc2.example.com" \
    "10.0.2.100"

# Check the logs
sudo tail -50 /var/log/efm-aap-failover.log

# Verify AAP scaled up
oc get pods -n ansible-automation-platform
```

### Test 2: EFM Test Failover

```bash
# Perform a test failover using EFM CLI
sudo /usr/edb/efm-4.x/bin/efm promote efm-cluster -switchover

# Monitor EFM logs
sudo tail -f /var/log/efm-4.x/efm-startup.log

# Verify AAP was scaled up
oc get deployments -n ansible-automation-platform
```

### Test 3: Simulated Database Failure

```bash
# Stop primary database (in test environment only!)
sudo systemctl stop postgresql-16

# Watch EFM detect failure and promote standby
sudo tail -f /var/log/efm-4.x/efm-startup.log

# Verify AAP activation
oc get pods -n ansible-automation-platform --watch
```

## Advanced Configuration

### Parallel Script Execution

For complex failover scenarios, execute multiple scripts:

**File**: `/usr/edb/efm-4.x/bin/efm-orchestrated-failover.sh`

```bash
#!/bin/bash
#
# Orchestrated Failover - Multiple Actions
#

set -e

LOGFILE="/var/log/efm-orchestrated-failover.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

log_message "Starting orchestrated failover..."

# Step 1: Update DNS (if managing DNS programmatically)
log_message "Updating DNS records..."
/usr/local/bin/update-dns-failover.sh

# Step 2: Scale up AAP cluster
log_message "Scaling up AAP cluster..."
/usr/edb/efm-4.x/bin/efm-aap-failover-wrapper.sh "$@"

# Step 3: Notify monitoring systems
log_message "Sending notifications..."
/usr/local/bin/send-failover-notification.sh "Database failover completed"

# Step 4: Update load balancer (if managing programmatically)
log_message "Updating load balancer configuration..."
/usr/local/bin/update-load-balancer.sh "dc2"

log_message "Orchestrated failover complete!"
```

### Conditional Execution Based on Time of Day

```bash
#!/bin/bash
#
# Time-aware failover script
#

HOUR=$(date +%H)
DAY=$(date +%u)

# Only auto-scale AAP during business hours (8am-6pm, Mon-Fri)
if [ "$DAY" -le 5 ] && [ "$HOUR" -ge 8 ] && [ "$HOUR" -le 18 ]; then
    /usr/edb/efm-4.x/bin/efm-aap-failover-wrapper.sh "$@"
else
    # Outside business hours - send alert for manual intervention
    /usr/local/bin/send-alert.sh "Database failover detected outside business hours"
fi
```

## Monitoring EFM Script Execution

Create a monitoring script to track EFM script executions:

```bash
#!/bin/bash
#
# Monitor EFM script execution
#

# Check last EFM script execution
LAST_EXECUTION=$(grep "EFM AAP Failover Script" /var/log/efm-aap-failover.log | tail -1)

if [ -n "$LAST_EXECUTION" ]; then
    echo "Last EFM failover script execution:"
    echo "$LAST_EXECUTION"
    
    # Check if execution was successful
    if grep -q "AAP cluster scaled up successfully" /var/log/efm-aap-failover.log; then
        echo "Status: SUCCESS"
        exit 0
    else
        echo "Status: FAILED"
        exit 1
    fi
else
    echo "No EFM failover script executions found"
    exit 0
fi
```

## Troubleshooting and Rollback

For EFM integration troubleshooting (script execution, timeouts, OpenShift authentication, network connectivity) and rollback procedures when AAP fails to start during failover, see [Troubleshooting](troubleshooting.md).

## Best Practices

1. **Test Regularly**: Schedule quarterly failover drills
2. **Monitor Logs**: Set up log aggregation for EFM and AAP script logs
3. **Timeout Tuning**: Allow sufficient time for AAP pods to start (5-10 minutes)
4. **Idempotency**: Ensure scripts can be run multiple times safely
5. **Error Handling**: Scripts should exit with appropriate codes (0=success, non-zero=failure)
6. **Notifications**: Send alerts when scripts execute or fail
7. **Documentation**: Keep runbooks updated with latest script versions
8. **Version Control**: Track script changes in Git
9. **Rollback Plan**: Always have manual fallback procedures
10. **Security**: Restrict script permissions to efm user only

## Integration with AAP Job Templates

For additional automation, create AAP Job Templates that can be triggered during failover:

```bash
# Call AAP job template from EFM script
curl -k -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AAP_TOKEN" \
  https://aap.example.com/api/v2/job_templates/123/launch/ \
  -d '{"extra_vars": {"datacenter": "dc2", "action": "failover"}}'
```

This allows complex orchestration workflows to be managed through AAP's workflow capabilities while still being triggered by EFM during database failover events.
