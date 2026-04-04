# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-04-03

### Added

#### Documentation - April 2026
- **[2026-04-03]** Comprehensive AAP 2.6 components reference guide ([#36](https://github.com/Red-Hat-EnterpriseDB-Testing/EDB_Testing/pull/36))
  - Complete deployment reference for Gateway, Controller, Hub, and EDA
  - Database architecture documentation (4 databases on 1 PostgreSQL instance)
  - Advanced HA configuration example with replicas and resource limits
  - Verification procedures and troubleshooting guide
  - Scaling guidance and resource sizing recommendations
- **[2026-04-03]** AAP 2.6 deployment validation reports ([#35](https://github.com/Red-Hat-EnterpriseDB-Testing/EDB_Testing/pull/35))
  - Comprehensive 18-section validation report against Red Hat documentation
  - Executive summary with deployment readiness checklist
  - 100% compliance validation (14/14 requirements passed)
  - Real deployment validation with CloudNativePG PostgreSQL cluster
- **[2026-04-03]** AAP OpenShift external DB deployment report ([#34](https://github.com/Red-Hat-EnterpriseDB-Testing/EDB_Testing/pull/34))
  - Documented successful 10-pod deployment (Gateway, Controller, Redis)
  - Environment-specific deployment insights
  - Skills symlink for easier access
- **[2026-04-03]** Reorganized scripts documentation with comprehensive guides ([#33](https://github.com/Red-Hat-EnterpriseDB-Testing/EDB_Testing/pull/33))
  - Scripts operations guide with deployment and DR workflows
  - Detailed scripts library reference for all shared functions
  - Scripts hooks and CI/CD integration guide
- **[2026-04-02]** HAProxy/PgBouncer architectural analysis ([#32](https://github.com/Red-Hat-EnterpriseDB-Testing/EDB_Testing/pull/32))
  - Comprehensive routing architecture analysis for EDB PostgreSQL
  - Comparison of HAProxy vs PgBouncer for AAP workloads
  - Connection pooling and health check configurations
  - Performance and scalability considerations
- PostgreSQL replication test reports
  - Cross-cluster replication validation
  - RTO/RPO measurement results
  - Streaming replication verification
- Reports directory structure with README
  - Organized validation and deployment reports
  - Clear categorization and indexing

#### Documentation - March 2026
- **[2026-03-31]** Improved main README with badges, prerequisites, and community links ([#31](https://github.com/Red-Hat-EnterpriseDB-Testing/EDB_Testing/pull/31))
  - Added status badges (License, Status, Last Updated)
  - Enhanced prerequisites section with detailed requirements
  - Improved quick start navigation and structure
- **[2026-03-31]** AAP 2.6 containerized DR architectures and validation ([#29](https://github.com/Red-Hat-EnterpriseDB-Testing/EDB_Testing/pull/29))
  - Enterprise DR architecture documentation
  - Containerized growth architecture patterns
  - Architecture validation reports
- **[2026-03-31]** Comprehensive Quick Start Guide ([#25](https://github.com/Red-Hat-EnterpriseDB-Testing/EDB_Testing/pull/25))
  - OpenShift deployment path (15 minutes)
  - RHEL with TPA deployment path (20 minutes)
  - Local CRC testing path (30 minutes)
  - Prerequisites and troubleshooting sections
- **[2026-03-31]** Refactored architecture into dedicated file ([#26](https://github.com/Red-Hat-EnterpriseDB-Testing/EDB_Testing/pull/26))
  - Moved architecture details to docs/architecture.md
  - Improved documentation organization and navigation
  - Enhanced diagrams and technical depth
- **[2026-03-31]** Documentation infrastructure improvements
  - Comprehensive documentation index (docs/INDEX.md)
  - Fixed cross-references across all documentation
  - Standardized terminology for EDB Postgres on OpenShift
  - Added table of contents and navigation aids
- **[2026-03-27]** Standardized namespace and cluster naming conventions
  - Updated all documentation with consistent naming
  - Clarified deployment architecture across datacenters
  - Improved configuration examples
- **[2026-03-25]** Enhanced OpenShift/Kubernetes deployment documentation
  - Improved deployment instructions and prerequisites
  - Added Trusted Postgres Architect (TPA) integration guide
  - Expanded troubleshooting guidance

#### Features
- **[2026-03-31]** Added Apache 2.0 license file ([#27](https://github.com/Red-Hat-EnterpriseDB-Testing/EDB_Testing/pull/27))
  - Added proper open-source licensing
  - Included license headers guidance

### Changed

- **[2026-04-03]** Clarified AAP 2.6 parent CR pattern in all deployment documentation ([#35](https://github.com/Red-Hat-EnterpriseDB-Testing/EDB_Testing/pull/35))
  - Updated to reference AnsibleAutomationPlatform parent CR instead of individual component CRs
  - Added specific field paths for all four component database secrets
  - Enhanced inline documentation for database connection parameters

### Fixed

#### Bug Fixes - March 2026
- **[2026-03-31]** Renamed .github/README.md to WORKFLOWS.md to fix main README display ([#30](https://github.com/Red-Hat-EnterpriseDB-Testing/EDB_Testing/pull/30))
  - GitHub was showing .github/README.md instead of root README.md
  - Resolved by renaming to WORKFLOWS.md
- **[2026-03-31]** Fixed CloudNativePG operator deployment issues ([#28](https://github.com/Red-Hat-EnterpriseDB-Testing/EDB_Testing/pull/28))
  - Resolved operator installation failures
  - Fixed cluster bootstrap configuration
  - Corrected storage class references
- **[2026-03-31]** Improved README formatting for better GitHub rendering ([#24](https://github.com/Red-Hat-EnterpriseDB-Testing/EDB_Testing/pull/24))
  - Fixed Markdown rendering issues
  - Improved table formatting
  - Enhanced code block syntax
- **[2026-03-31]** Resolved YAML validation and Kustomize build failures
  - Fixed YAML syntax errors across all manifests
  - Corrected Kustomize configuration issues
  - Validated all YAML files pass CI/CD checks
- **[2026-03-31]** Resolved ShellCheck warnings in all shell scripts
  - Fixed quote handling and variable expansion
  - Corrected shellcheck violations
  - Improved script robustness
- **[2026-03-31]** Fixed YAML indentation and security scan issues
  - Corrected indentation across all YAML files
  - Resolved security scan findings
  - Enhanced secret handling
- **[2026-03-31]** Resolved CI/CD validation failures
  - Fixed GitHub Actions workflow issues
  - Corrected linting and validation steps
  - Ensured all checks pass

## Validation Status

### AAP 2.6 Compliance
- ✅ **Overall Compliance**: 100% (14/14 requirements validated)
- ✅ **Parent CR Pattern**: Correct use of AnsibleAutomationPlatform CR
- ✅ **Platform Gateway**: Properly configured with dedicated database
- ✅ **External PostgreSQL**: Four databases correctly configured
- ✅ **Operator Installation**: Correct stable-2.6 channel
- ✅ **Security**: Two-layer password validation, no hardcoded credentials

### Infrastructure Validation
- ✅ **CloudNativePG Integration**: Verified with 2-instance cluster
- ✅ **External Database Configuration**: 4 databases on 1 PostgreSQL instance
- ✅ **Replication**: Cross-cluster streaming replication validated
- ✅ **CI/CD Pipelines**: All YAML validations passing
- ✅ **Security Scans**: All ShellCheck and security issues resolved

### Deployment Verification
- ✅ **OpenShift Deployment**: Successfully deployed on OpenShift 4.12+
- ✅ **Gateway**: 2 pods operational
- ✅ **Controller**: 7 pods operational (3 web, 4 task)
- ✅ **Redis**: 1 pod operational
- ✅ **PostgreSQL**: 2-instance cluster with replication

## Links

- [GitHub Repository](https://github.com/Red-Hat-EnterpriseDB-Testing/EDB_Testing)
- [Documentation Index](docs/INDEX.md)
- [Quick Start Guide](docs/quick-start-guide.md)
- [Contributing Guide](CONTRIBUTING.md)
- [License](LICENSE)
