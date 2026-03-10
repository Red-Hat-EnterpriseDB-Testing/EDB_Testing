# Changelog

All notable changes to the edb.postgres_operations collection will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-06

### Added

#### Roles
- **deploy_cluster** role for deploying PostgreSQL clusters
  - Namespace creation and management
  - Secret management for pull secrets and credentials
  - Customizable cluster configuration
  - Storage and resource configuration
  - Monitoring integration
  - High availability support with PodDisruptionBudgets
  - Wait for cluster ready functionality
  - Comprehensive deployment summary output

- **execute_sql** role for SQL query execution
  - Single query execution
  - Multiple query support
  - SQL file execution
  - Transaction mode support
  - Selective host filtering (all, primary, production, etc.)
  - Query result display and saving
  - Execution time measurement
  - Error handling and retry logic
  - AAP logging integration

- **check_health** role for cluster health monitoring
  - Operator health checks
  - Cluster status monitoring
  - Replication lag detection
  - Pod health and restart monitoring
  - PVC status checking
  - Service endpoint validation
  - AAP webhook notifications
  - Health report generation (JSON, YAML, text formats)
  - Configurable alerting thresholds

#### Playbooks
- `deploy-cluster.yml` - Cluster deployment playbook
- `execute-sql.yml` - SQL execution playbook
- `check-health.yml` - Health monitoring playbook
- `site.yml` - Main orchestration playbook with operation selection

#### Configuration
- Collection metadata (galaxy.yml)
- Comprehensive default variables for all roles
- Role metadata and dependencies
- Example inventory for multi-datacenter setup
- Ansible configuration (ansible.cfg)

#### Documentation
- Collection README with quick start guide
- Individual README for each role
- Usage examples and common use cases
- AAP integration guide
- Security best practices
- Troubleshooting section

### Features

- **Multi-Datacenter Support**: Deploy and manage clusters across multiple OpenShift datacenters
- **AAP Integration**: Full Ansible Automation Platform support with webhooks and workflows
- **Security**: Ansible Vault support, credential management, RBAC configuration
- **Monitoring**: Health checks, replication monitoring, alerting
- **Flexibility**: Highly configurable roles with sensible defaults
- **Error Handling**: Comprehensive error handling and recovery options
- **Reporting**: Generate health reports in multiple formats
- **Transaction Support**: SQL execution with transaction mode
- **Wait Logic**: Intelligent waiting for cluster readiness

### Dependencies

- Ansible Core >= 2.14
- kubernetes.core >= 2.3.0
- community.postgresql >= 2.0.0
- Python kubernetes library
- Python psycopg2-binary library

### Requirements

- OpenShift/Kubernetes cluster with EDB Postgres operator installed
- Valid kubeconfig files
- EDB subscription credentials
- Appropriate RBAC permissions

## [1.1.0] - 2026-02-10

### Added

#### New Roles

- **manage_aap_cluster** role for AAP cluster management
  - OpenShift pod scaling (scale_up, scale_down)
  - RHEL systemd service management (start, stop)
  - Cluster status checks and monitoring
  - Health checks with AAP API validation
  - Support for both OpenShift and RHEL deployments
  - Wait for pods ready with configurable timeouts
  - Automatic service ordering for proper startup/shutdown
  - Comprehensive logging and error handling

- **efm_integration** role for EDB Failover Manager integration
  - Install integration scripts to EFM nodes
  - Configure EFM properties for automated failover
  - Setup OpenShift kubeconfig for efm user
  - Test integration before production deployment
  - Support for orchestrated failover with notifications
  - Backup and restore EFM configuration
  - Uninstall capability
  - Email and Slack notification support

#### New Playbooks

- `manage-aap-cluster.yml` - General-purpose AAP cluster management
  - Scale OpenShift pods up/down
  - Start/stop RHEL services
  - Check cluster status
  - Flexible variable configuration

- `setup-efm-integration.yml` - Complete EFM integration setup
  - Install integration scripts
  - Configure EFM properties
  - Optional testing phase
  - Post-installation instructions

- `disaster-recovery-failover.yml` - End-to-end DR orchestration
  - Source datacenter verification
  - AAP cluster activation in target datacenter
  - Health checks and validation
  - Safety confirmations
  - Rollback capabilities
  - Complete operational summary

#### Scripts

Bash scripts for direct integration with EFM:
- `scale-aap-up.sh` - Scale AAP pods to operational state
- `scale-aap-down.sh` - Scale AAP pods to zero
- `start-aap-cluster.sh` - Start AAP systemd services
- `stop-aap-cluster.sh` - Stop AAP systemd services
- `efm-aap-failover-wrapper.sh` - EFM integration wrapper
- `efm-orchestrated-failover.sh` - Advanced orchestration
- `monitor-efm-scripts.sh` - Monitoring and status checking
- `aap-cluster.service` - Systemd service unit
- `efm.properties.sample` - Sample EFM configuration

#### Documentation

- `AAP_MANAGEMENT.md` - Comprehensive guide for AAP management
  - Architecture overview
  - Quick start guide
  - Role and playbook documentation
  - Configuration examples
  - Integration with AAP workflows
  - Testing procedures
  - Troubleshooting guide
  - Best practices

- Individual role READMEs with:
  - Detailed variable documentation
  - Usage examples
  - Integration patterns
  - Disaster recovery procedures

- Scripts README with:
  - Installation instructions
  - Usage examples
  - EFM integration setup
  - Troubleshooting tips

### Enhanced

#### Collection Metadata

- Updated `galaxy.yml` to version 1.1.0
- Added new tags: aap, ansible, disaster_recovery, failover, efm
- Updated description to include AAP and DR capabilities

#### Main README

- Added "Ansible Automation" section
- Documented role capabilities
- Added Ansible vs Bash comparison table
- Included workflow integration examples
- Added testing guidance

### Features

- **Automated Failover**: Complete automation for database failover with AAP activation
- **Dual Approach**: Both Bash scripts (for EFM) and Ansible roles (for complex workflows)
- **Safety Features**: Confirmation prompts, check mode support, rollback procedures
- **Monitoring**: Built-in monitoring and logging capabilities
- **Notifications**: Email and Slack notification support
- **Testing**: Built-in test capabilities for all integrations
- **Idempotency**: All Ansible roles are fully idempotent
- **Multi-Platform**: Support for both OpenShift and RHEL deployments
- **Production-Ready**: Comprehensive error handling and validation

### Integration

- **EFM Integration**: Seamless integration with EDB Failover Manager
- **AAP Workflows**: Can be called from AAP Workflow Templates
- **Multi-Datacenter**: Full support for DR scenarios across datacenters
- **Health Checks**: Automatic health validation during failover

## [Unreleased]

### Planned Features

- Backup and restore role
- Database migration role
- Performance tuning role
- Metrics collection and visualization
- Custom resource validation
- Integration tests with Molecule
- CI/CD pipeline examples
- Advanced monitoring dashboards

---

## Version History

- **1.1.0** (2026-02-10) - Added AAP cluster management and EFM integration
- **1.0.0** (2026-02-06) - Initial release with core functionality
