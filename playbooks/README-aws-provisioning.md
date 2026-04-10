# AAP Multi-Region AWS Infrastructure Provisioning

Ansible playbook to provision Ansible Automation Platform infrastructure across AWS regions (us-east-1 and us-west-1) with RDS PostgreSQL for disaster recovery.

## Architecture

Based on: [`docs/aap-containerized-enterprise-dr-architecture.md`](../docs/aap-containerized-enterprise-dr-architecture.md)

**Deployment:**
- **DC1 (us-east-1):** Primary datacenter with active AAP cluster
- **DC2 (us-west-1):** Standby datacenter with stopped AAP instances
- **Database:** RDS PostgreSQL with cross-region read replica
- **Network:** VPC peering for cross-region connectivity

**Resources Provisioned:**
- 2 VPCs (one per region)
- VPC peering connection
- 18 EC2 instances (9 per region):
  - 2 Platform Gateway nodes
  - 2 Automation Controller nodes
  - 2 Automation Hub nodes
  - 2 Event-Driven Ansible nodes
  - 1 HAProxy database router
- 2 RDS PostgreSQL instances (primary + read replica)
- Security groups, subnets, route tables

## Prerequisites

### 1. AWS Credentials

Configure AWS credentials with permissions to create:
- VPC, Subnets, Route Tables, Internet Gateways
- VPC Peering
- EC2 Instances
- RDS Instances
- Security Groups

```bash
# Using AWS CLI
aws configure

# Or environment variables
export AWS_ACCESS_KEY_ID='your-access-key'
export AWS_SECRET_ACCESS_KEY='your-secret-key'
export AWS_DEFAULT_REGION='us-east-1'
```

### 2. SSH Key Pairs

Create SSH key pairs in both regions:

```bash
# us-east-1
aws ec2 create-key-pair \
  --key-name aap-dr-key-us-east-1 \
  --region us-east-1 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/aap-dr-us-east-1.pem
chmod 400 ~/.ssh/aap-dr-us-east-1.pem

# us-west-1
aws ec2 create-key-pair \
  --key-name aap-dr-key-us-west-1 \
  --region us-west-1 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/aap-dr-us-west-1.pem
chmod 400 ~/.ssh/aap-dr-us-west-1.pem
```

### 3. Ansible Collections

Install required Ansible collections:

```bash
ansible-galaxy collection install -r requirements.yml
```

### 4. Python Dependencies

Install boto3 for AWS modules:

```bash
pip install boto3 botocore
```

### 5. PostgreSQL Client (for database setup)

```bash
# macOS
brew install postgresql

# RHEL/CentOS
dnf install postgresql
```

## Configuration

### Update Variables

Edit [`vars/aws-infrastructure.yml`](vars/aws-infrastructure.yml):

```yaml
# Update RHEL AMI IDs (find latest in your regions)
rhel_ami_us_east_1: ami-XXXXXXXXXXXXXXXXX
rhel_ami_us_west_1: ami-XXXXXXXXXXXXXXXXX

# Update SSH key names (if different)
ssh_key_name_dc1: aap-dr-key-us-east-1
ssh_key_name_dc2: aap-dr-key-us-west-1

# Configure RDS instance class
rds_instance_class: db.r6g.2xlarge  # 8 vCPU, 64GB RAM

# Adjust network CIDRs if needed
dc1_vpc_cidr: 10.1.0.0/16
dc2_vpc_cidr: 10.2.0.0/16
```

### Set Secrets

**Option 1: Environment Variables (Recommended)**

```bash
export RDS_MASTER_PASSWORD='YourSecureRDSPassword123!'
export AAP_DB_PASSWORD='YourSecureAAPPassword456!'
```

**Option 2: Ansible Vault**

```bash
# Create vault file
ansible-vault create vars/secrets.yml

# Add:
# rds_master_password: YourSecureRDSPassword123!
# aap_db_password: YourSecureAAPPassword456!

# Update playbook to include:
# vars_files:
#   - vars/secrets.yml
```

## Usage

### Step 1: Provision Infrastructure

```bash
ansible-playbook provision-aap-aws-multiregion.yml
```

**Expected Duration:** 30-45 minutes (RDS creation is the longest step)

### Step 2: Verify Provisioning

```bash
# Check DC1 VPC
aws ec2 describe-vpcs \
  --region us-east-1 \
  --filters "Name=tag:Name,Values=aap-dr-vpc-dc1"

# Check DC1 RDS
aws rds describe-db-instances \
  --region us-east-1 \
  --db-instance-identifier aap-dr-postgres-dc1

# Check DC1 EC2 instances
aws ec2 describe-instances \
  --region us-east-1 \
  --filters "Name=tag:Project,Values=aap-dr" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],State.Name,PrivateIpAddress,PublicIpAddress]' \
  --output table
```

### Step 3: Create AAP Databases

The playbook includes a second play to create databases. Run separately after RDS is ready:

```bash
# Set RDS endpoint
export RDS_ENDPOINT=$(aws rds describe-db-instances \
  --region us-east-1 \
  --db-instance-identifier aap-dr-postgres-dc1 \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

# Run database setup
ansible-playbook provision-aap-aws-multiregion.yml \
  --tags database-setup
```

### Step 4: Generate Dynamic Inventory

Create inventory from provisioned infrastructure:

```bash
# Use AWS dynamic inventory
ansible-inventory -i aws_ec2.yml --graph

# Or export to static file
ansible-inventory -i aws_ec2.yml --list > inventory/aws-provisioned.yml
```

## Post-Provisioning Steps

### 1. Configure HAProxy

SSH to HAProxy instances and configure PostgreSQL routing:

```bash
# DC1 HAProxy
ssh -i ~/.ssh/aap-dr-us-east-1.pem ec2-user@<haproxy-dc1-public-ip>

# Install HAProxy
sudo dnf install -y haproxy

# Configure (see docs/aap-containerized-enterprise-dr-architecture.md section 4.3)
sudo vi /etc/haproxy/haproxy.cfg

# Update backend to point to RDS endpoint
# backend postgresql_backend
#   server rds-primary <RDS_ENDPOINT>:5432 check inter 5s
```

### 2. Install AAP

Use AAP containerized installer on all component nodes:

```bash
# On each AAP node (gateway, controller, hub, eda)
sudo dnf install -y podman

# Download AAP installer
# Follow: docs/aap-containerized-enterprise-dr-architecture.md section 4.2
```

### 3. Configure Failover Automation

Set up scripts to:
- Monitor RDS replica lag
- Promote RDS replica in DC2 during failover
- Start AAP instances in DC2
- Update Route53/Global Load Balancer

## Cost Estimation

**Monthly AWS Costs (approximate):**

| Resource | DC1 | DC2 | Monthly Cost |
|----------|-----|-----|--------------|
| EC2 Instances (t3.xlarge × 8) | Running | Stopped | ~$950 |
| EC2 HAProxy (t3.large × 1) | Running | Running | ~$120 |
| RDS Primary (db.r6g.2xlarge Multi-AZ) | Running | - | ~$1,200 |
| RDS Replica (db.r6g.2xlarge) | - | Running | ~$600 |
| Data Transfer (inter-region) | - | - | ~$100 |
| EBS Storage (gp3) | - | - | ~$50 |
| **Total** | | | **~$3,020/month** |

**Cost Optimization:**
- Stop DC2 instances when not testing (save ~$475/month)
- Use Reserved Instances for 1-year commitment (save ~30%)
- Consider Single-AZ RDS for non-production

## Disaster Recovery Testing

### Simulate Failover

```bash
# 1. Promote RDS read replica in DC2
aws rds promote-read-replica \
  --region us-west-1 \
  --db-instance-identifier aap-dr-postgres-dc2

# 2. Start DC2 AAP instances
aws ec2 start-instances \
  --region us-west-1 \
  --instance-ids $(aws ec2 describe-instances \
    --region us-west-1 \
    --filters "Name=tag:Project,Values=aap-dr" "Name=tag:Datacenter,Values=DC2" "Name=tag:Role,Values=aap-component" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text)

# 3. Stop DC1 AAP instances
aws ec2 stop-instances \
  --region us-east-1 \
  --instance-ids $(aws ec2 describe-instances \
    --region us-east-1 \
    --filters "Name=tag:Project,Values=aap-dr" "Name=tag:Datacenter,Values=DC1" "Name=tag:Role,Values=aap-component" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text)
```

## Cleanup

### Destroy All Resources

**⚠️ WARNING: This will delete ALL provisioned resources**

```bash
# Delete RDS instances (must be done first due to deletion protection)
aws rds modify-db-instance \
  --region us-east-1 \
  --db-instance-identifier aap-dr-postgres-dc1 \
  --no-deletion-protection \
  --apply-immediately

aws rds delete-db-instance \
  --region us-east-1 \
  --db-instance-identifier aap-dr-postgres-dc1 \
  --skip-final-snapshot

# Wait for DC2 replica to be deletable
aws rds delete-db-instance \
  --region us-west-1 \
  --db-instance-identifier aap-dr-postgres-dc2 \
  --skip-final-snapshot

# Terminate EC2 instances
aws ec2 terminate-instances \
  --region us-east-1 \
  --instance-ids $(aws ec2 describe-instances \
    --region us-east-1 \
    --filters "Name=tag:Project,Values=aap-dr" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text)

aws ec2 terminate-instances \
  --region us-west-1 \
  --instance-ids $(aws ec2 describe-instances \
    --region us-west-1 \
    --filters "Name=tag:Project,Values=aap-dr" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text)

# Wait for instances to terminate, then delete VPCs, subnets, etc.
# (Use AWS Console or additional cleanup scripts)
```

## Troubleshooting

### Issue: RDS Creation Fails

```bash
# Check RDS subnet group
aws rds describe-db-subnet-groups \
  --region us-east-1 \
  --db-subnet-group-name aap-dr-rds-subnet-group-dc1

# Verify subnets are in different AZs
aws ec2 describe-subnets \
  --region us-east-1 \
  --filters "Name=tag:Project,Values=aap-dr"
```

### Issue: VPC Peering Not Working

```bash
# Check peering connection status
aws ec2 describe-vpc-peering-connections \
  --filters "Name=tag:Project,Values=aap-dr"

# Verify route tables
aws ec2 describe-route-tables \
  --region us-east-1 \
  --filters "Name=tag:Project,Values=aap-dr"
```

### Issue: Cannot Connect to EC2 Instances

```bash
# Verify security group allows SSH
aws ec2 describe-security-groups \
  --region us-east-1 \
  --filters "Name=tag:Project,Values=aap-dr" "Name=tag:Name,Values=*aap*"

# Check if instances have public IPs
aws ec2 describe-instances \
  --region us-east-1 \
  --filters "Name=tag:Project,Values=aap-dr" \
  --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],PublicIpAddress]'
```

## Related Documentation

- [AAP Containerized Enterprise DR Architecture](../docs/aap-containerized-enterprise-dr-architecture.md)
- [AAP Installation Guide](../docs/install-aap-containerized.md)
- [DR Testing Guide](../docs/dr-testing-guide.md)
- [HAProxy Configuration](../docs/haproxy-pgbouncer-architectural-analysis.md)

## Support

For issues or questions:
- Review architecture documentation
- Check AWS CloudWatch logs
- Verify security group rules
- Ensure RDS is in 'available' state before AAP installation
