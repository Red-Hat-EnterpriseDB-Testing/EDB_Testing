# Tests and CI Infrastructure

This directory contains all testing, validation, and CI/CD related scripts and manifests.

## Directory Structure

```
tests/
├── scripts/          # Test and validation scripts
│   ├── dr-failover-test.sh
│   ├── measure-rto-rpo.sh
│   ├── validate-aap-data.sh
│   ├── test-split-brain-prevention.sh
│   ├── generate-dr-report.sh
│   └── run-ci-checks-locally.sh
├── hooks/            # Pre-commit and CI hooks
│   ├── check-script-permissions.sh
│   └── validate-openshift-manifests.sh
├── openshift/        # OpenShift test manifests
│   └── dr-testing/   # DR testing CronJob and resources
└── lib/              # Shared test libraries (if needed)
```

## Test Scripts

### DR Testing
- **dr-failover-test.sh** - Automated DR failover testing
- **measure-rto-rpo.sh** - RTO/RPO measurement and reporting
- **validate-aap-data.sh** - AAP data integrity validation
- **generate-dr-report.sh** - DR test report generation

### Unit/Integration Tests
- **test-split-brain-prevention.sh** - Split-brain prevention testing
- **run-ci-checks-locally.sh** - Local CI pipeline validation

## CI Hooks

Pre-commit hooks integrated with `.pre-commit-config.yaml`:
- **check-script-permissions.sh** - Verify script executability
- **validate-openshift-manifests.sh** - Kubernetes manifest validation

## OpenShift Testing

CronJob-based automated DR testing deployed to OpenShift clusters. See `openshift/dr-testing/README.md` for details.

## Usage

**Run local CI checks:**
```bash
./tests/scripts/run-ci-checks-locally.sh
```

**Run DR failover test:**
```bash
./tests/scripts/dr-failover-test.sh --dc1-context <dc1> --dc2-context <dc2>
```

**Measure RTO/RPO:**
```bash
./tests/scripts/measure-rto-rpo.sh --dc1-context <dc1> --dc2-context <dc2>
```

**Validate AAP data:**
```bash
./tests/scripts/validate-aap-data.sh create-baseline <context>
./tests/scripts/validate-aap-data.sh validate <context>
```

See individual script documentation for detailed usage.
