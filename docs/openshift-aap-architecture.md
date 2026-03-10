# OpenShift AAP Architecture

AAP deployment architecture (resource sizing) and operational procedures for managing AAP on OpenShift: scaling pods to zero in the standby datacenter and scaling back up for failover or testing. For RHEL-based AAP (systemctl), see [RHEL AAP Architecture](rhel-aap-architecture.md).

[← Back to main README](../README.md#aap-deployment-architecture)

## AAP Deployment Architecture

### AAP on OpenShift

#### Resource Requirements

**Per Datacenter:**
- **AAP Controller**: 3 pods × (4 CPU, 8GB RAM)
- **Automation Hub**: 2 pods × (2 CPU, 4GB RAM)
- **AAP Database**: 3 pods × (2 CPU, 4GB RAM)
- **Total**: ~18 CPUs, 36GB RAM per datacenter

