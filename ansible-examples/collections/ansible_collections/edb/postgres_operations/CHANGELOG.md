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

## [Unreleased]

### Planned Features

- Backup and restore role
- Database migration role
- Performance tuning role
- DR failover automation role
- Metrics collection and visualization
- Custom resource validation
- Integration tests with Molecule
- CI/CD pipeline examples

---

## Version History

- **1.0.0** (2026-02-06) - Initial release with core functionality
