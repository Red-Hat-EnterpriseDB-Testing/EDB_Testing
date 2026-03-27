# AAP Cluster Management Scripts

This directory contains scripts for managing Ansible Automation Platform (AAP) clusters in both RHEL-based and OpenShift-based deployments.

For a short **runbook** (when to scale, DR cautions), see **[`docs/manual-scripts-doc.md`](../docs/manual-scripts-doc.md)**.

## OpenShift Scripts

### scale-aap-down.sh

Scales AAP pods to zero replicas on OpenShift. Useful for conserving resources in standby datacenters.

**Usage:**

Update the default cluster context in the script to match your cluster context from your kubeconfig file (`kubectl config get-contexts`).

```bash
# Using default context (set DEFAULT_CLUSTER_CONTEXT in script)
./scripts/scale-aap-down.sh

# Specifying context explicitly
./scripts/scale-aap-down.sh <your-cluster-context>
```

**What it does:**

- Switches to the specified OpenShift context
- Scales down all AAP deployments to 0 replicas
- Verifies pods have terminated
- Database pods are intentionally NOT scaled down

### scale-aap-up.sh

Restores AAP pods to operational replica counts on OpenShift.

**Usage:**

Update the default cluster context in the script to match your cluster context from your kubeconfig file (`kubectl config get-contexts`).

```bash
# Using default context (set DEFAULT_CLUSTER_CONTEXT in script)
./scripts/scale-aap-up.sh

# Specifying context explicitly
./scripts/scale-aap-up.sh <your-cluster-context>
```

**What it does:**

- Switches to the specified OpenShift context
- Scales up all AAP deployments to their target replica counts
- Waits for pods to be ready (up to 5 minutes)
- Displays AAP URL for verification

**Target Replica Counts:**

- AAP Gateway: 3 replicas
- Controller Task: 3 replicas
- Controller Web: 3 replicas
- Automation Hub API: 2 replicas
- Automation Hub Content: 2 replicas
- Automation Hub Worker: 2 replicas
- Operators: 1 replica each

## RHEL Scripts

### start-aap-cluster.sh

Starts all AAP systemd services on a RHEL server in the correct order.

**Installation:**

```bash
# Copy script to system location
sudo cp scripts/start-aap-cluster.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/start-aap-cluster.sh

# Run manually
sudo /usr/local/bin/start-aap-cluster.sh
```

**What it does:**

- Starts PostgreSQL database
- Starts Redis cache
- Starts Receptor service
- Starts AAP Controller
- Starts Automation Hub
- Starts Nginx web server
- Verifies AAP API is responding
- Logs all operations to `/var/log/aap-startup.log`

### stop-aap-cluster.sh

Stops all AAP systemd services on a RHEL server in reverse order.

**Installation:**

```bash
# Copy script to system location
sudo cp scripts/stop-aap-cluster.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/stop-aap-cluster.sh

# Run manually
sudo /usr/local/bin/stop-aap-cluster.sh
```

**What it does:**

- Stops services in reverse dependency order
- Logs all operations to `/var/log/aap-shutdown.log`

### aap-cluster.service

Systemd service unit for managing AAP cluster as a single service.

**Installation:**

```bash
# Copy service file to systemd directory
sudo cp scripts/aap-cluster.service /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Enable service to start on boot
sudo systemctl enable aap-cluster.service

# Start the service
sudo systemctl start aap-cluster.service

# Check status
sudo systemctl status aap-cluster.service
```

**Management:**

```bash
# Start AAP cluster
sudo systemctl start aap-cluster.service

# Stop AAP cluster
sudo systemctl stop aap-cluster.service

# Restart AAP cluster
sudo systemctl restart aap-cluster.service

# Check status
sudo systemctl status aap-cluster.service

# View logs
sudo journalctl -u aap-cluster.service -f
```

## Prerequisites

### OpenShift Scripts

- OpenShift CLI (`oc`) installed and configured
- Valid kubeconfig file with access to target cluster
- Appropriate RBAC permissions to scale deployments
- Network connectivity to OpenShift API

### RHEL Scripts

- RHEL 8 or 9 with AAP installed
- Root or sudo access
- AAP installed via standard installer
- Systemd services properly configured

## Troubleshooting

### OpenShift

**Context not found:**

```bash
# List available contexts
oc config get-contexts

# Use the correct context name from the list
./scripts/scale-aap-up.sh <correct-context-name>
```

**Namespace not found:**

```bash
# Verify namespace exists
oc get namespaces | grep ansible

# Update NAMESPACE variable in script if different
```

**Pods not scaling:**

```bash
# Check deployment status
oc get deployments -n ansible-automation-platform

# Check for resource quotas
oc get resourcequota -n ansible-automation-platform

# Check events for errors
oc get events -n ansible-automation-platform --sort-by='.lastTimestamp'
```

### RHEL

**Service not found:**

```bash
# List installed AAP services
systemctl list-units | grep -E "automation|receptor|postgresql|redis"

# Update AAP_SERVICES array in script to match your installation
```

**Permission denied:**

```bash
# Scripts must run as root
sudo ./scripts/start-aap-cluster.sh
```

**API not responding:**

```bash
# Check AAP Controller logs
sudo journalctl -u automation-controller.service -f

# Check nginx configuration
sudo nginx -t

# Verify firewall rules
sudo firewall-cmd --list-all
```

## Integration with Disaster Recovery

These scripts can be integrated into disaster recovery runbooks:

### Failover (DC1 → DC2)

```bash
# 1. Scale up AAP in DC2 (use your DC2 cluster context from kubeconfig)
./scripts/scale-aap-up.sh <dc2-cluster-context>

# 2. Wait for pods to be ready (script does this automatically)

# 3. Verify AAP is accessible
AAP_URL=$(oc get route -n ansible-automation-platform -o jsonpath='{.items[0].spec.host}')
curl -k https://$AAP_URL/api/v2/ping/

# 4. Update global load balancer to point to DC2
```

### Failback (DC2 → DC1)

```bash
# 1. Scale up AAP in DC1 (use your DC1 cluster context from kubeconfig)
./scripts/scale-aap-up.sh <dc1-cluster-context>

# 2. Verify AAP in DC1 is healthy

# 3. Update global load balancer to point to DC1

# 4. Scale down AAP in DC2 (conserve resources)
./scripts/scale-aap-down.sh <dc2-cluster-context>
```

## Monitoring

Add these scripts to monitoring systems:

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

## Automation

These scripts can be called from:

- Ansible playbooks for automated DR procedures
- Monitoring systems for auto-remediation
- CI/CD pipelines for environment management
- Cron jobs for scheduled maintenance windows

## EFM Integration Scripts

### efm-aap-failover-wrapper.sh

Wrapper script called by EDB Failover Manager (EFM) during database failover events. Automatically scales up AAP in the datacenter where the database is being promoted.

**Installation:**

```bash
# Copy to EFM bin directory
sudo cp scripts/efm-aap-failover-wrapper.sh /usr/edb/efm-4.x/bin/
sudo chown efm:efm /usr/edb/efm-4.x/bin/efm-aap-failover-wrapper.sh
sudo chmod +x /usr/edb/efm-4.x/bin/efm-aap-failover-wrapper.sh

# Configure EFM to call this script
sudo vi /etc/edb/efm-4.x/efm.properties

# Add this line:
# script.post.promotion=/usr/edb/efm-4.x/bin/efm-aap-failover-wrapper.sh %h %s %a %v

# Restart EFM
sudo systemctl restart edb-efm-4.x
```

**What it does:**

- Receives parameters from EFM (cluster name, node type, address, VIP)
- Determines which datacenter the promoted node is in
- Scales up AAP if node is being promoted to primary
- Logs all operations to `/var/log/efm-aap-failover.log`
- Supports both OpenShift and RHEL deployments

**Testing:**

```bash
# Test script manually (simulate EFM call)
sudo -u efm /usr/edb/efm-4.x/bin/efm-aap-failover-wrapper.sh \
    "prod-db" \
    "standby" \
    "prod-db-replica-dc2.example.com" \
    "10.0.2.100"

# Check logs
sudo tail -f /var/log/efm-aap-failover.log
```

### efm-orchestrated-failover.sh

Advanced orchestration script that coordinates multiple failover actions including AAP activation, notifications, and monitoring updates.

**Installation:**

```bash
# Copy to EFM bin directory
sudo cp scripts/efm-orchestrated-failover.sh /usr/edb/efm-4.x/bin/
sudo chown efm:efm /usr/edb/efm-4.x/bin/efm-orchestrated-failover.sh
sudo chmod +x /usr/edb/efm-4.x/bin/efm-orchestrated-failover.sh

# Configure EFM to use orchestrated failover
sudo vi /etc/edb/efm-4.x/efm.properties

# Add this line:
# script.post.promotion=/usr/edb/efm-4.x/bin/efm-orchestrated-failover.sh %h %s %a %v
```

**What it does:**

1. Calls the AAP failover wrapper to scale up AAP
2. Waits for AAP to become fully operational (health check)
3. Sends notifications via email, Slack, and syslog
4. Updates monitoring system annotations
5. Logs complete orchestration workflow

**Customization:**

Edit the script to add your environment-specific actions:

- Update notification targets (email, Slack webhook)
- Add DNS update logic
- Integrate with load balancer API
- Add monitoring system updates

### monitor-efm-scripts.sh

Monitoring script to check the status and history of EFM failover script executions.

**Usage:**

```bash
# Check EFM script execution status
./scripts/monitor-efm-scripts.sh

# Run from cron for continuous monitoring
# Add to crontab:
# */5 * * * * /path/to/monitor-efm-scripts.sh | logger -t efm-monitor
```

**What it shows:**

- Last execution timestamp and details
- Cluster name, node type, and datacenter
- Success/failure status
- Execution statistics (total, successful, failed)
- Success rate percentage
- Recent execution history
- Log file locations

### efm.properties.sample

Sample EFM configuration file showing how to integrate AAP failover scripts.

**Usage:**

```bash
# Review the sample configuration
cat scripts/efm.properties.sample

# Copy relevant sections to your EFM configuration
sudo vi /etc/edb/efm-4.x/efm.properties
```

**Key settings:**

- `enable.custom.scripts=true` - Enable script execution
- `script.timeout=300` - Script timeout in seconds
- `script.post.promotion` - Script to run after promotion
- `script.post.failure` - Script to run after failure detection

## EFM Integration Setup

Complete setup procedure for EFM integration:

### 1. Install AAP Management Scripts

```bash
# Copy AAP scaling scripts
sudo cp scripts/scale-aap-up.sh /usr/edb/efm-4.x/bin/aap-failover.sh
sudo cp scripts/scale-aap-down.sh /usr/edb/efm-4.x/bin/aap-failback.sh
sudo chmod +x /usr/edb/efm-4.x/bin/aap-*.sh
```

### 2. Install EFM Wrapper Scripts

```bash
# Copy EFM wrapper and orchestration scripts
sudo cp scripts/efm-aap-failover-wrapper.sh /usr/edb/efm-4.x/bin/
sudo cp scripts/efm-orchestrated-failover.sh /usr/edb/efm-4.x/bin/
sudo chown efm:efm /usr/edb/efm-4.x/bin/efm-*.sh
sudo chmod +x /usr/edb/efm-4.x/bin/efm-*.sh
```

### 3. Configure OpenShift Access for EFM User

```bash
# Create kubeconfig directory for efm user
sudo mkdir -p /var/lib/efm/.kube

# Copy kubeconfig
sudo cp /path/to/your/kubeconfig /var/lib/efm/.kube/config

# Set ownership
sudo chown -R efm:efm /var/lib/efm/.kube

# Test access
sudo -u efm oc --kubeconfig=/var/lib/efm/.kube/config get nodes
```

### 4. Update EFM Configuration

```bash
# Edit EFM properties
sudo vi /etc/edb/efm-4.x/efm.properties

# Add these lines:
enable.custom.scripts=true
script.timeout=300
script.post.promotion=/usr/edb/efm-4.x/bin/efm-aap-failover-wrapper.sh %h %s %a %v
```

### 5. Test the Integration

```bash
# Test script execution
sudo -u efm /usr/edb/efm-4.x/bin/efm-aap-failover-wrapper.sh \
    "test-cluster" \
    "standby" \
    "dc2-database-host" \
    "10.0.2.100"

# Check logs
sudo tail -50 /var/log/efm-aap-failover.log

# Monitor script status
./scripts/monitor-efm-scripts.sh
```

### 6. Restart EFM

```bash
# Restart EFM to apply changes
sudo systemctl restart edb-efm-4.x

# Verify EFM is running
sudo systemctl status edb-efm-4.x

# Check EFM logs
sudo tail -f /var/log/efm-4.x/efm-startup.log
```

### 7. Set Up Monitoring

```bash
# Install monitoring script
sudo cp scripts/monitor-efm-scripts.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/monitor-efm-scripts.sh

# Add to crontab for regular monitoring
crontab -e
# Add: */5 * * * * /usr/local/bin/monitor-efm-scripts.sh >> /var/log/efm-monitor.log
```

## Troubleshooting EFM Integration

### Script Not Executing

```bash
# Check EFM configuration
sudo grep script /etc/edb/efm-4.x/efm.properties

# Verify script exists and is executable
ls -l /usr/edb/efm-4.x/bin/efm-aap-failover-wrapper.sh

# Check EFM logs for errors
sudo grep -i script /var/log/efm-4.x/efm-startup.log

# Test script as efm user
sudo -u efm /usr/edb/efm-4.x/bin/efm-aap-failover-wrapper.sh test standby test test
```

### Permission Issues

```bash
# Ensure correct ownership
sudo chown efm:efm /usr/edb/efm-4.x/bin/*.sh

# Ensure execute permissions
sudo chmod +x /usr/edb/efm-4.x/bin/*.sh

# Check kubeconfig access
sudo -u efm ls -la /var/lib/efm/.kube/

# Test oc command as efm user
sudo -u efm oc --kubeconfig=/var/lib/efm/.kube/config whoami
```

### Script Timeout

```bash
# Increase timeout in efm.properties
sudo vi /etc/edb/efm-4.x/efm.properties
# Change: script.timeout=600

# Restart EFM
sudo systemctl restart edb-efm-4.x
```

### Check Script Logs

```bash
# View AAP failover logs
sudo tail -100 /var/log/efm-aap-failover.log

# View orchestrated failover logs
sudo tail -100 /var/log/efm-orchestrated-failover.log

# View EFM logs
sudo tail -100 /var/log/efm-4.x/efm-startup.log

# Search for errors
sudo grep -i error /var/log/efm-aap-failover.log
```

## License

These scripts are provided as examples for managing AAP clusters. Modify as needed for your environment.
