# Troubleshooting

This document covers troubleshooting and rollback procedures for the AAP with EDB Postgres multi-datacenter architecture, with emphasis on EFM (Enterprise Failover Manager) integration.

[← Back to main README](../README.md#aap-cluster-management)

## Troubleshooting EFM Integration

### Issue: Script Not Executing

```bash
# Check EFM configuration
sudo cat /etc/edb/efm-4.x/efm.properties | grep script

# Verify script permissions
ls -l /usr/edb/efm-4.x/bin/efm-aap-failover-wrapper.sh

# Check EFM user has execute permissions
sudo -u efm /usr/edb/efm-4.x/bin/efm-aap-failover-wrapper.sh test test test test

# Review EFM logs for errors
sudo grep -i "script" /var/log/efm-4.x/efm-startup.log
```

### Issue: Script Timeout

```bash
# Increase timeout in efm.properties
script.timeout=600  # Increase to 10 minutes

# Restart EFM
sudo systemctl restart edb-efm-4.x
```

### Issue: OpenShift Authentication

```bash
# Ensure efm user has access to kubeconfig
sudo mkdir -p /var/lib/efm/.kube
sudo cp ~/.kube/kubeconfig /var/lib/efm/.kube/config
sudo chown -R efm:efm /var/lib/efm/.kube

# Update wrapper script to use correct kubeconfig
export KUBECONFIG=/var/lib/efm/.kube/config
```

### Issue: Network Connectivity

```bash
# Test connectivity from efm user
sudo -u efm oc --kubeconfig=/var/lib/efm/.kube/config get nodes

# Check firewall rules
sudo firewall-cmd --list-all

# Verify DNS resolution
sudo -u efm nslookup api.youropenshiftapi
```

## Rollback Procedures

If AAP fails to start during EFM failover:

```bash
# 1. Check what went wrong
sudo tail -100 /var/log/efm-aap-failover.log

# 2. Manually scale up AAP
./scripts/scale-aap-up.sh api-changeme:6443

# 3. Or for RHEL deployments
sudo systemctl start aap-cluster.service

# 4. Verify AAP is operational
curl -k https://aap-dc2.apps.ocp2.example.com/api/v2/ping/

# 5. If still failing, failback to original primary
sudo /usr/edb/efm-4.x/bin/efm promote efm-cluster -switchover
```
