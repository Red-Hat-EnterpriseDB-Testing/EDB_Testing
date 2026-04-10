# Scripts Directory

This directory contains automation scripts for managing Ansible Automation Platform (AAP) clusters and disaster recovery operations.

## Quick Reference

For comprehensive documentation, see **[`docs/scripts-guide.md`](../docs/scripts-guide.md)**.

## Script Categories

### AAP Cluster Management (OpenShift)

Scripts for managing AAP on OpenShift/Kubernetes:

- **[`scale-aap-up.sh`](scale-aap-up.sh)** - Scale AAP pods to operational replica counts
- **[`scale-aap-down.sh`](scale-aap-down.sh)** - Scale AAP pods to zero for standby mode
- **Configuration**: [`aap-cluster.service`](aap-cluster.service) - Systemd service unit for RHEL

### AAP Cluster Management (RHEL)

Scripts for managing AAP on RHEL servers:

- **[`start-aap-cluster.sh`](start-aap-cluster.sh)** - Start all AAP systemd services
- **[`stop-aap-cluster.sh`](stop-aap-cluster.sh)** - Stop all AAP systemd services

### EFM Integration

Scripts for EDB Failover Manager integration:

- **[`efm-aap-failover-wrapper.sh`](efm-aap-failover-wrapper.sh)** - Wrapper called by EFM during failover
- **[`efm-orchestrated-failover.sh`](efm-orchestrated-failover.sh)** - Orchestrated failover with notifications
- **[`monitor-efm-scripts.sh`](monitor-efm-scripts.sh)** - Monitor EFM script execution
- **Configuration**: [`efm.properties.sample`](efm.properties.sample) - Sample EFM configuration

### Shared Libraries

Reusable code libraries (in `lib/`):

- **[`lib/aap-scaling.sh`](lib/aap-scaling.sh)** - Common AAP scaling functions
- **[`lib/logging.sh`](lib/logging.sh)** - Standardized logging functions

## Testing and CI

All testing, validation, and CI/CD infrastructure has been moved to the **[`tests/`](../tests/)** directory:

- **DR Testing Scripts**: `tests/scripts/` - Failover testing, RTO/RPO measurement, data validation
- **CI Hooks**: `tests/hooks/` - Pre-commit hooks for code quality
- **OpenShift Testing**: `tests/openshift/dr-testing/` - CronJob-based automated testing

See **[`tests/README.md`](../tests/README.md)** for complete testing documentation.

## Quick Start

### Scale AAP Up (OpenShift)

```bash
# Scale up AAP in a specific cluster
./scripts/scale-aap-up.sh <cluster-context>
```

### Run DR Testing

DR testing scripts have moved to `tests/scripts/`. See **[`tests/README.md`](../tests/README.md)**.

## Prerequisites

- **OpenShift Scripts**: `oc` CLI, valid kubeconfig, RBAC permissions
- **RHEL Scripts**: Root/sudo access, AAP installed via standard installer
- **DR Testing**: Access to both DC1 and DC2 clusters

## Documentation

Comprehensive guides are available in the `docs/` directory:

- **[scripts-guide.md](../docs/scripts-guide.md)** - Complete guide to all scripts
- **[dr-testing-guide.md](../docs/dr-testing-guide.md)** - DR testing procedures
- **[manual-scripts-doc.md](../docs/manual-scripts-doc.md)** - Runbooks and manual procedures

## Common Workflows

### Disaster Recovery Failover

```bash
# 1. Scale up AAP in standby DC
./scripts/scale-aap-up.sh <dc2-context>

# 2. Validate data integrity (see tests/)
./tests/scripts/validate-aap-data.sh validate <dc2-context>

# 3. Generate DR report (see tests/)
./tests/scripts/generate-dr-report.sh --latest
```

### EFM Integration Setup

```bash
# 1. Copy scripts to EFM directory
sudo cp scripts/efm-*.sh /usr/edb/efm-4.x/bin/

# 2. Configure EFM (see docs/scripts-guide.md)
sudo vi /etc/edb/efm-4.x/efm.properties

# 3. Test the integration
sudo -u efm /usr/edb/efm-4.x/bin/efm-aap-failover-wrapper.sh test standby test test
```

### Local CI Checks

```bash
# Run all quality checks before committing
./tests/scripts/run-ci-checks-locally.sh
```

## Support

For issues, questions, or contributions, see the main [README.md](../README.md).
