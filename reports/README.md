# Test Reports

This directory contains test reports and validation results for the EDB PostgreSQL deployment project.

## Reports

| Report | Date | Description |
|--------|------|-------------|
| [REPLICATION-TEST-REPORT-20260402.md](REPLICATION-TEST-REPORT-20260402.md) | 2026-04-02 | PostgreSQL replication testing on CRC OpenShift - comprehensive test suite including failover, data consistency, and performance metrics |

## Report Types

### Replication Tests
Tests covering:
- Streaming replication functionality
- Data consistency across primary and replicas
- Read-only enforcement on replicas
- Replication lag measurements
- Automatic failover capability
- Post-failover recovery

### Performance Tests
Metrics including:
- Replication lag (write/flush/replay)
- Bulk insert performance
- Failover time
- Recovery time

### High Availability Tests
Validations for:
- Automatic primary promotion
- Replica synchronization
- Zero data loss verification
- Service routing

## Future Reports

Additional test reports will be added here as the project progresses, including:
- Cross-datacenter replication tests
- Backup and restore validation
- DR testing results
- Performance benchmarks
- AAP integration tests
