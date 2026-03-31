# DR Testing Automation — OpenShift deployment

Automated disaster recovery testing with scheduled CronJob execution.

## Quick Deploy

### Prerequisites

1. **Kubeconfig with multi-cluster access:**
   ```bash
   # Create secret with kubeconfig that has access to both DC1 and DC2
   oc create secret generic dr-test-kubeconfig \
     --from-file=config=$HOME/.kube/config \
     -n edb-postgres
   ```

2. **Update cluster contexts:**
   Edit `kustomization.yaml` and set actual cluster context names:
   ```yaml
   - dc1-context=your-dc1-context-name
   - dc2-context=your-dc2-context-name
   ```

3. **Configure notifications (optional):**
   - Slack webhook URL
   - PagerDuty token

### Deploy

```bash
# Deploy all resources
oc apply -k .

# Verify deployment
oc get cronjob -n edb-postgres
oc get pvc -n edb-postgres | grep dr-test
```

## Schedule

**Default schedule:** Quarterly on first Saturday at 02:00 UTC
- Months: January, April, July, October
- Day: First Saturday (days 1-7, weekday 6)
- Time: 02:00 UTC

**Cron expression:** `0 2 1-7 1,4,7,10 6`

### Modify Schedule

Edit `cronjob-dr-test.yaml`:

```yaml
spec:
  # Monthly on first Saturday
  schedule: "0 2 1-7 * 6"

  # Every Sunday at 03:00
  schedule: "0 3 * * 0"

  # First day of every quarter
  schedule: "0 2 1 1,4,7,10 *"
```

## Manual Execution

### Trigger Test Immediately

```bash
# Create a one-time Job from CronJob
oc create job dr-test-manual --from=cronjob/dr-test-quarterly -n edb-postgres

# Watch progress
oc logs -f job/dr-test-manual -n edb-postgres
```

### Run Locally

```bash
# Use scripts directly (not via OpenShift workload objects)
cd /path/to/EDB_Testing/scripts

./dr-failover-test.sh \
  --dc1-context dc1-cluster \
  --dc2-context dc2-cluster \
  --test-id manual-test-$(date +%Y%m%d)
```

## Monitoring

### Check CronJob Status

```bash
# View CronJob details
oc describe cronjob dr-test-quarterly -n edb-postgres

# List recent jobs
oc get jobs -n edb-postgres -l app=dr-testing

# View last run
oc logs -l app=dr-testing --tail=100 -n edb-postgres
```

### Access Test Results

```bash
# List PVC contents
POD=$(oc get pods -n edb-postgres -l app=dr-testing -o name | head -1)
oc exec -n edb-postgres $POD -- ls -lh /tmp/dr-test-results/

# Copy results locally
oc rsync -n edb-postgres $POD:/tmp/dr-test-results/ ./local-results/
```

## Notifications

### Slack Integration

1. Create Slack webhook: https://api.slack.com/messaging/webhooks

2. Update secret in `kustomization.yaml`:
   ```yaml
   secretGenerator:
   - name: dr-test-secrets
     literals:
     - slack-webhook-url=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
   ```

3. Redeploy:
   ```bash
   oc apply -k .
   ```

**Notifications sent:**
- Test start
- Test completion (success/failure)

### PagerDuty Integration

1. Get PagerDuty API token

2. Create service in PagerDuty and note service ID

3. Update `cronjob-dr-test.yaml`:
   ```yaml
   env:
   - name: PAGERDUTY_SERVICE_ID
     value: "YOUR_SERVICE_ID"
   ```

4. Update secret and redeploy

**Alerts triggered:**
- Test failure (low urgency)

## Troubleshooting

### CronJob Not Running

```bash
# Check if CronJob is suspended
oc get cronjob dr-test-quarterly -n edb-postgres -o yaml | grep suspend

# Unsuspend if needed
oc patch cronjob dr-test-quarterly -n edb-postgres -p '{"spec":{"suspend":false}}'

# Check schedule
oc describe cronjob dr-test-quarterly -n edb-postgres | grep Schedule
```

### Permission Errors

```bash
# Verify ServiceAccount exists
oc get sa dr-test-service-account -n edb-postgres

# Check ClusterRoleBinding
oc get clusterrolebinding dr-test-cluster-role-binding

# View permissions
oc describe clusterrole dr-test-cluster-role
```

### Script Errors

```bash
# View recent job logs
JOB=$(oc get jobs -n edb-postgres -l app=dr-testing --sort-by=.metadata.creationTimestamp -o name | tail -1)
oc logs -n edb-postgres $JOB

# Check ConfigMap has scripts
oc get configmap dr-test-scripts -n edb-postgres -o yaml
```

### Storage Issues

```bash
# Check PVC status
oc get pvc dr-test-results-pvc -n edb-postgres

# Check available space
POD=$(oc run test-shell --image=busybox --restart=Never -n edb-postgres --rm -it -- sh)
# In pod: df -h /tmp/dr-test-results
```

## Customization

### Adjust Test Parameters

Edit `cronjob-dr-test.yaml` command section:

```yaml
command:
- /bin/bash
- -c
- |
  /scripts/dr-failover-test.sh \
    --test-id "$TEST_ID" \
    --dc1-context "$DC1_CONTEXT" \
    --dc2-context "$DC2_CONTEXT" \
    --skip-failback \
    --dry-run  # Add this for testing
```

### Resource Limits

Adjust based on cluster size:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### Timeout

Change active deadline:

```yaml
spec:
  jobTemplate:
    spec:
      activeDeadlineSeconds: 7200  # 2 hours (default)
```

## Cleanup

### Remove All Resources

```bash
# Delete CronJob and related resources
oc delete -k .

# Delete PVC (WARNING: destroys test results)
oc delete pvc dr-test-results-pvc -n edb-postgres

# Delete kubeconfig secret
oc delete secret dr-test-kubeconfig -n edb-postgres
```

### Delete Old Test Results

```bash
# Manual cleanup of old tests
POD=$(oc get pods -n edb-postgres -l app=dr-testing -o name | head -1)
oc exec -n edb-postgres $POD -- find /tmp/dr-test-results/ -type f -mtime +90 -delete
```

## Production Recommendations

1. **Build Container Image:**
   - Don't use ConfigMap for scripts
   - Build custom image with all scripts baked in
   - Push to internal registry

2. **Secure Credentials:**
   - Use Vault or External Secrets Operator
   - Don't store secrets in Git

3. **Monitoring:**
   - Create ServiceMonitor for Prometheus
   - Alert on test failures
   - Track RTO/RPO trends

4. **Results Retention:**
   - Increase PVC size for long-term storage
   - Export results to S3 or external storage
   - Set up log forwarding

5. **Review Process:**
   - Assign DRI (Directly Responsible Individual)
   - Post-test review meeting
   - Update runbooks quarterly

## References

- [DR Test Scripts](../../scripts/dr-failover-test.sh)
- [DR Testing Documentation](../../docs/dr-testing-guide.md)
- [OpenShift: Working with cron jobs](https://docs.openshift.com/container-platform/latest/applications/workloads/cronjobs.html)
