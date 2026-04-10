# AAP Multi-Region AWS Playbooks Overview

Automated infrastructure provisioning for Ansible Automation Platform on AWS with RDS PostgreSQL.

## 📁 Directory Structure

```
playbooks/
├── PLAYBOOK-OVERVIEW.md                    # This file
├── README-aws-provisioning.md              # Detailed provisioning guide
├── requirements.yml                         # Ansible collection dependencies
├── provision-aap-aws-multiregion.yml       # Main infrastructure provisioning playbook
├── configure-haproxy.yml                   # HAProxy database router configuration
│
├── vars/
│   ├── aws-infrastructure.yml              # Infrastructure configuration variables
│   └── secrets.example.yml                 # Secrets template (encrypt with Ansible Vault)
│
├── templates/
│   └── haproxy.cfg.j2                      # HAProxy configuration template
│
├── inventory/
│   └── aws_ec2.yml                         # AWS EC2 dynamic inventory
│
└── scripts/
    └── get-infrastructure-info.sh          # Helper script to retrieve resource info
```

## 🚀 Quick Start

### 1. Prerequisites

```bash
# Install Ansible collections
ansible-galaxy collection install -r requirements.yml

# Install Python dependencies
pip install boto3 botocore

# Configure AWS credentials
aws configure
```

### 2. Create Secrets

```bash
# Copy template and edit
cp vars/secrets.example.yml vars/secrets.yml
vi vars/secrets.yml

# Encrypt with Ansible Vault
ansible-vault encrypt vars/secrets.yml

# Set environment variables (alternative to vault)
export RDS_MASTER_PASSWORD='YourSecurePassword123!'
export AAP_DB_PASSWORD='YourSecurePassword456!'
```

### 3. Update Configuration

Edit `vars/aws-infrastructure.yml`:
- Update RHEL AMI IDs for your regions
- Adjust instance types if needed
- Verify network CIDRs don't conflict with existing infrastructure

### 4. Provision Infrastructure

```bash
# Full provisioning (30-45 minutes)
ansible-playbook provision-aap-aws-multiregion.yml

# Or with vault password
ansible-playbook provision-aap-aws-multiregion.yml --ask-vault-pass -e @vars/secrets.yml
```

### 5. Get Infrastructure Details

```bash
# Run helper script
./scripts/get-infrastructure-info.sh

# Export RDS endpoints
export RDS_DC1_ENDPOINT='aap-dr-postgres-dc1.xxxxx.us-east-1.rds.amazonaws.com'
export RDS_DC2_ENDPOINT='aap-dr-postgres-dc2.xxxxx.us-west-1.rds.amazonaws.com'
```

### 6. Configure HAProxy

```bash
# Use dynamic inventory
ansible-playbook configure-haproxy.yml -i inventory/aws_ec2.yml

# Verify HAProxy stats
curl http://<haproxy-public-ip>:8404/stats
```

## 📋 Playbook Details

### Main Provisioning Playbook

**File:** `provision-aap-aws-multiregion.yml`

**What it does:**
- ✅ Creates VPCs in us-east-1 and us-west-1
- ✅ Sets up subnets (application + database per region)
- ✅ Configures VPC peering for cross-region connectivity
- ✅ Creates security groups with proper firewall rules
- ✅ Provisions 18 EC2 instances (9 per region):
  - 2 Platform Gateway nodes
  - 2 Automation Controller nodes
  - 2 Automation Hub nodes
  - 2 Event-Driven Ansible nodes
  - 1 HAProxy database router
- ✅ Creates RDS PostgreSQL primary (DC1)
- ✅ Creates RDS PostgreSQL read replica (DC2)
- ✅ Configures RDS with AAP-optimized parameters
- ✅ Creates AAP databases (awx, automationhub, automationedacontroller, automationgateway)

**Runtime:** 30-45 minutes

### HAProxy Configuration Playbook

**File:** `configure-haproxy.yml`

**What it does:**
- ✅ Installs HAProxy on database router instances
- ✅ Configures PostgreSQL connection routing
- ✅ Deploys health check scripts
- ✅ Sets up HAProxy stats interface
- ✅ Configures firewall rules

**Runtime:** 5-10 minutes

## 🏗️ Architecture Deployed

```
┌─────────────────────────────────────────────────────────────────┐
│                     Global Load Balancer                        │
│                  (configure after provisioning)                 │
└────────────┬──────────────────────────────┬─────────────────────┘
             │                              │
┌────────────▼─────────────┐   ┌────────────▼──────────────────┐
│   DC1 (us-east-1)        │   │   DC2 (us-west-1)             │
│   PRIMARY - ACTIVE       │   │   STANDBY - STOPPED           │
│                          │   │                               │
│  VPC: 10.1.0.0/16        │   │  VPC: 10.2.0.0/16             │
│                          │   │                               │
│  AAP Components (8):     │   │  AAP Components (8):          │
│   - 2 Gateway            │   │   - 2 Gateway (stopped)       │
│   - 2 Controller         │   │   - 2 Controller (stopped)    │
│   - 2 Hub                │   │   - 2 Hub (stopped)           │
│   - 2 EDA                │   │   - 2 EDA (stopped)           │
│                          │   │                               │
│  HAProxy (1):            │   │  HAProxy (1):                 │
│   - DB Router            │   │   - DB Router                 │
│                          │   │                               │
│  RDS PostgreSQL:         │   │  RDS PostgreSQL:              │
│   - Primary (Multi-AZ)   │◄──┤   - Read Replica              │
│   - db.r6g.2xlarge       │   │   - db.r6g.2xlarge            │
│   - 500GB gp3            │   │   - 500GB gp3                 │
└──────────────────────────┘   └───────────────────────────────┘
         │                                   │
         └──────── VPC Peering ──────────────┘
```

## 🔧 Post-Provisioning Tasks

### 1. Verify Infrastructure

```bash
# Check all resources
./scripts/get-infrastructure-info.sh

# Test VPC peering
ssh -i ~/.ssh/aap-dr-us-east-1.pem ec2-user@<dc1-instance-ip>
ping <dc2-instance-private-ip>

# Test RDS connectivity
psql -h $RDS_DC1_ENDPOINT -U postgres -d postgres
```

### 2. Install AAP

On each AAP component instance (gateway, controller, hub, eda):

```bash
# SSH to instance
ssh -i ~/.ssh/aap-dr-us-east-1.pem ec2-user@<instance-ip>

# Install Podman
sudo dnf install -y podman

# Download AAP containerized installer
# (follow Red Hat documentation)

# Run installer with inventory pointing to HAProxy
```

### 3. Configure Failover

Create automation to:
- Monitor RDS replication lag
- Promote DC2 read replica on failure
- Start DC2 AAP instances
- Update DNS/load balancer

## 📊 Resource Summary

| Component | DC1 (us-east-1) | DC2 (us-west-1) | Total |
|-----------|-----------------|-----------------|-------|
| **VPCs** | 1 | 1 | 2 |
| **Subnets** | 3 | 3 | 6 |
| **EC2 (AAP)** | 8 running | 8 stopped | 16 |
| **EC2 (HAProxy)** | 1 running | 1 running | 2 |
| **RDS** | 1 primary (Multi-AZ) | 1 replica | 2 |
| **Security Groups** | 3 | 3 | 6 |
| **Monthly Cost** | ~$2,200 | ~$820 | **~$3,020** |

## 🔐 Security Considerations

### Secrets Management

**Do NOT commit these to Git:**
- `vars/secrets.yml` (encrypted or not)
- SSH private keys (`~/.ssh/aap-dr-*.pem`)
- Database passwords

**Use Ansible Vault:**
```bash
# Encrypt
ansible-vault encrypt vars/secrets.yml

# Edit
ansible-vault edit vars/secrets.yml

# Run playbook
ansible-playbook playbook.yml --ask-vault-pass -e @vars/secrets.yml
```

### Network Security

**Security Groups Implemented:**
- AAP components: Only necessary ports open (443, 80, 8080-8445, 6379, 27199)
- HAProxy: PostgreSQL (5432) + Stats (8404)
- RDS: Only accessible from HAProxy + cross-region replication

**Recommendations:**
- Restrict SSH (port 22) to bastion host or VPN
- Enable VPC Flow Logs
- Use AWS Systems Manager Session Manager instead of SSH
- Enable AWS GuardDuty for threat detection

### Compliance

**Implemented:**
- ✅ Encryption at rest (EBS, RDS)
- ✅ Encryption in transit (TLS for RDS)
- ✅ Network segmentation (VPC, subnets)
- ✅ Security groups (least privilege)
- ✅ Multi-AZ for RDS primary (HA)

**TODO:**
- [ ] AWS Config rules
- [ ] AWS CloudTrail logging
- [ ] Automated compliance scanning
- [ ] AWS Backup policies

## 💰 Cost Optimization

### Current Design
- **Monthly:** ~$3,020
- **Annual:** ~$36,240

### Optimization Options

**1. Reserved Instances (1-year commitment)**
- Save ~30% on EC2 and RDS
- New monthly: ~$2,100
- Annual savings: ~$11,000

**2. Stop DC2 Instances When Not Testing**
- Save ~$475/month when DC2 stopped
- Manual start for DR drills

**3. Right-size Instances**
- Test with smaller instance types in dev/staging
- Monitor actual resource usage

**4. Use Savings Plans**
- Flexible compute savings plans
- 1-year or 3-year commitment

**5. Development Environment**
- Single-region deployment
- Single-AZ RDS
- Smaller instance types
- Cost: ~$800/month

## 🧪 Testing Scenarios

### DR Failover Test

```bash
# 1. Create baseline
./tests/scripts/validate-aap-data.sh create-baseline

# 2. Promote DC2 RDS
aws rds promote-read-replica \
  --region us-west-1 \
  --db-instance-identifier aap-dr-postgres-dc2

# 3. Start DC2 instances
aws ec2 start-instances \
  --region us-west-1 \
  --instance-ids $(aws ec2 describe-instances \
    --region us-west-1 \
    --filters "Name=tag:Datacenter,Values=DC2" "Name=tag:Role,Values=aap-component" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text)

# 4. Validate
./tests/scripts/validate-aap-data.sh validate
```

### RTO/RPO Measurement

```bash
# Automated testing
./tests/scripts/measure-rto-rpo.sh --dc1-context dc1 --dc2-context dc2

# Expected:
# - RTO: < 5 minutes
# - RPO: < 5 seconds (streaming replication)
```

## 📚 Related Documentation

- **[README-aws-provisioning.md](README-aws-provisioning.md)** - Detailed provisioning guide
- **[Architecture](../docs/aap-containerized-enterprise-dr-architecture.md)** - Full architecture documentation
- **[DR Testing](../docs/dr-testing-guide.md)** - DR testing framework
- **[HAProxy Analysis](../docs/haproxy-pgbouncer-architectural-analysis.md)** - Database routing design

## 🆘 Troubleshooting

### RDS Creation Fails

**Error:** Subnet group requires subnets in at least 2 availability zones

**Solution:**
```bash
# Verify subnets are in different AZs
aws ec2 describe-subnets \
  --region us-east-1 \
  --filters "Name=tag:Project,Values=aap-dr"
```

### VPC Peering Not Working

**Error:** Cannot ping across regions

**Solution:**
```bash
# Check peering connection status
aws ec2 describe-vpc-peering-connections \
  --filters "Name=tag:Project,Values=aap-dr"

# Verify route tables have peering routes
aws ec2 describe-route-tables \
  --region us-east-1 \
  --filters "Name=tag:Project,Values=aap-dr"
```

### SSH Connection Refused

**Solution:**
1. Verify security group allows SSH from your IP
2. Check EC2 instance state is "running"
3. Verify public IP is assigned
4. Use correct SSH key

### HAProxy Health Checks Failing

**Solution:**
```bash
# SSH to HAProxy instance
ssh -i ~/.ssh/aap-dr-us-east-1.pem ec2-user@<haproxy-ip>

# Test PostgreSQL connectivity
pg_isready -h $RDS_DC1_ENDPOINT -U postgres

# Check HAProxy logs
sudo journalctl -u haproxy -f
```

## 📝 Maintenance

### Update RHEL AMIs

```bash
# Find latest RHEL 9.4 AMI
aws ec2 describe-images \
  --owners 309956199498 \
  --filters "Name=name,Values=RHEL-9.4*" \
  --query 'Images[*].[ImageId,Name,CreationDate]' \
  --region us-east-1 \
  --output table

# Update vars/aws-infrastructure.yml
```

### Rotate Secrets

```bash
# Update RDS password
aws rds modify-db-instance \
  --region us-east-1 \
  --db-instance-identifier aap-dr-postgres-dc1 \
  --master-user-password 'NewSecurePassword123!' \
  --apply-immediately

# Update secrets file
ansible-vault edit vars/secrets.yml
```

### Scale Resources

```bash
# Modify RDS instance class
aws rds modify-db-instance \
  --region us-east-1 \
  --db-instance-identifier aap-dr-postgres-dc1 \
  --db-instance-class db.r6g.4xlarge \
  --apply-immediately false  # Apply during maintenance window
```

## 🤝 Contributing

Follow project standards:
- Use `ansible-lint` before committing
- Test playbooks in non-production first
- Update documentation for any changes
- Follow Red Hat CoP Ansible best practices

---

**Version:** 1.0  
**Last Updated:** 2026-04-10  
**Maintainer:** Infrastructure Team
