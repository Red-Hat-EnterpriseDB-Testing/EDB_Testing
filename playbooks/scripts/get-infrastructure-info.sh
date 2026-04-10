#!/bin/bash
# Get AAP Multi-Region Infrastructure Information
# Retrieves details of provisioned AWS resources

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="${PROJECT_NAME:-aap-dr}"
DC1_REGION="${DC1_REGION:-us-east-1}"
DC2_REGION="${DC2_REGION:-us-west-1}"

# Functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*"
}

section_header() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}$*${NC}"
    echo -e "${GREEN}========================================${NC}"
}

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI not found. Please install: brew install awscli"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials not configured. Run: aws configure"
    exit 1
fi

log_success "AWS credentials validated"

# ===========================================
# VPC Information
# ===========================================
section_header "VPC Information"

log_info "Fetching DC1 VPC (${DC1_REGION})..."
DC1_VPC_ID=$(aws ec2 describe-vpcs \
    --region "${DC1_REGION}" \
    --filters "Name=tag:Name,Values=${PROJECT_NAME}-vpc-dc1" \
    --query 'Vpcs[0].VpcId' \
    --output text 2>/dev/null || echo "")

if [[ -n "$DC1_VPC_ID" && "$DC1_VPC_ID" != "None" ]]; then
    DC1_VPC_CIDR=$(aws ec2 describe-vpcs \
        --region "${DC1_REGION}" \
        --vpc-ids "${DC1_VPC_ID}" \
        --query 'Vpcs[0].CidrBlock' \
        --output text)
    log_success "DC1 VPC: ${DC1_VPC_ID} (${DC1_VPC_CIDR})"
else
    log_warning "DC1 VPC not found"
fi

log_info "Fetching DC2 VPC (${DC2_REGION})..."
DC2_VPC_ID=$(aws ec2 describe-vpcs \
    --region "${DC2_REGION}" \
    --filters "Name=tag:Name,Values=${PROJECT_NAME}-vpc-dc2" \
    --query 'Vpcs[0].VpcId' \
    --output text 2>/dev/null || echo "")

if [[ -n "$DC2_VPC_ID" && "$DC2_VPC_ID" != "None" ]]; then
    DC2_VPC_CIDR=$(aws ec2 describe-vpcs \
        --region "${DC2_REGION}" \
        --vpc-ids "${DC2_VPC_ID}" \
        --query 'Vpcs[0].CidrBlock' \
        --output text)
    log_success "DC2 VPC: ${DC2_VPC_ID} (${DC2_VPC_CIDR})"
else
    log_warning "DC2 VPC not found"
fi

# ===========================================
# RDS Information
# ===========================================
section_header "RDS PostgreSQL Instances"

log_info "Fetching DC1 RDS instance..."
RDS_DC1_INFO=$(aws rds describe-db-instances \
    --region "${DC1_REGION}" \
    --db-instance-identifier "${PROJECT_NAME}-postgres-dc1" \
    --query 'DBInstances[0].[Endpoint.Address,DBInstanceStatus,EngineVersion,DBInstanceClass]' \
    --output text 2>/dev/null || echo "")

if [[ -n "$RDS_DC1_INFO" ]]; then
    RDS_DC1_ENDPOINT=$(echo "$RDS_DC1_INFO" | awk '{print $1}')
    RDS_DC1_STATUS=$(echo "$RDS_DC1_INFO" | awk '{print $2}')
    RDS_DC1_VERSION=$(echo "$RDS_DC1_INFO" | awk '{print $3}')
    RDS_DC1_CLASS=$(echo "$RDS_DC1_INFO" | awk '{print $4}')

    log_success "DC1 RDS (PRIMARY):"
    echo "  Endpoint: ${RDS_DC1_ENDPOINT}"
    echo "  Status:   ${RDS_DC1_STATUS}"
    echo "  Version:  PostgreSQL ${RDS_DC1_VERSION}"
    echo "  Class:    ${RDS_DC1_CLASS}"

    # Export environment variable
    export RDS_DC1_ENDPOINT
    echo ""
    echo "  Export command:"
    echo "  export RDS_DC1_ENDPOINT='${RDS_DC1_ENDPOINT}'"
else
    log_warning "DC1 RDS instance not found"
fi

log_info "Fetching DC2 RDS instance..."
RDS_DC2_INFO=$(aws rds describe-db-instances \
    --region "${DC2_REGION}" \
    --db-instance-identifier "${PROJECT_NAME}-postgres-dc2" \
    --query 'DBInstances[0].[Endpoint.Address,DBInstanceStatus,EngineVersion,DBInstanceClass]' \
    --output text 2>/dev/null || echo "")

if [[ -n "$RDS_DC2_INFO" ]]; then
    RDS_DC2_ENDPOINT=$(echo "$RDS_DC2_INFO" | awk '{print $1}')
    RDS_DC2_STATUS=$(echo "$RDS_DC2_INFO" | awk '{print $2}')
    RDS_DC2_VERSION=$(echo "$RDS_DC2_INFO" | awk '{print $3}')
    RDS_DC2_CLASS=$(echo "$RDS_DC2_INFO" | awk '{print $4}')

    log_success "DC2 RDS (REPLICA):"
    echo "  Endpoint: ${RDS_DC2_ENDPOINT}"
    echo "  Status:   ${RDS_DC2_STATUS}"
    echo "  Version:  PostgreSQL ${RDS_DC2_VERSION}"
    echo "  Class:    ${RDS_DC2_CLASS}"

    # Export environment variable
    export RDS_DC2_ENDPOINT
    echo ""
    echo "  Export command:"
    echo "  export RDS_DC2_ENDPOINT='${RDS_DC2_ENDPOINT}'"
else
    log_warning "DC2 RDS instance not found"
fi

# ===========================================
# EC2 Instances
# ===========================================
section_header "EC2 Instances - DC1 (${DC1_REGION})"

log_info "Fetching DC1 instances..."
aws ec2 describe-instances \
    --region "${DC1_REGION}" \
    --filters "Name=tag:Project,Values=${PROJECT_NAME}" "Name=tag:Datacenter,Values=DC1" \
    --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],State.Name,InstanceType,PrivateIpAddress,PublicIpAddress]' \
    --output table

section_header "EC2 Instances - DC2 (${DC2_REGION})"

log_info "Fetching DC2 instances..."
aws ec2 describe-instances \
    --region "${DC2_REGION}" \
    --filters "Name=tag:Project,Values=${PROJECT_NAME}" "Name=tag:Datacenter,Values=DC2" \
    --query 'Reservations[].Instances[].[Tags[?Key==`Name`].Value|[0],State.Name,InstanceType,PrivateIpAddress,PublicIpAddress]' \
    --output table

# ===========================================
# HAProxy Instances
# ===========================================
section_header "HAProxy Database Routers"

log_info "Fetching HAProxy instances..."

HAPROXY_DC1=$(aws ec2 describe-instances \
    --region "${DC1_REGION}" \
    --filters "Name=tag:Project,Values=${PROJECT_NAME}" "Name=tag:Component,Values=haproxy" \
    --query 'Reservations[].Instances[].[PublicIpAddress,PrivateIpAddress]' \
    --output text 2>/dev/null || echo "")

if [[ -n "$HAPROXY_DC1" ]]; then
    HAPROXY_DC1_PUBLIC=$(echo "$HAPROXY_DC1" | awk '{print $1}')
    HAPROXY_DC1_PRIVATE=$(echo "$HAPROXY_DC1" | awk '{print $2}')
    log_success "DC1 HAProxy:"
    echo "  Public IP:  ${HAPROXY_DC1_PUBLIC}"
    echo "  Private IP: ${HAPROXY_DC1_PRIVATE}"
    echo "  Stats URL:  http://${HAPROXY_DC1_PUBLIC}:8404/stats"
    echo "  SSH:        ssh -i ~/.ssh/aap-dr-us-east-1.pem ec2-user@${HAPROXY_DC1_PUBLIC}"
else
    log_warning "DC1 HAProxy not found"
fi

HAPROXY_DC2=$(aws ec2 describe-instances \
    --region "${DC2_REGION}" \
    --filters "Name=tag:Project,Values=${PROJECT_NAME}" "Name=tag:Component,Values=haproxy" \
    --query 'Reservations[].Instances[].[PublicIpAddress,PrivateIpAddress]' \
    --output text 2>/dev/null || echo "")

if [[ -n "$HAPROXY_DC2" ]]; then
    HAPROXY_DC2_PUBLIC=$(echo "$HAPROXY_DC2" | awk '{print $1}')
    HAPROXY_DC2_PRIVATE=$(echo "$HAPROXY_DC2" | awk '{print $2}')
    log_success "DC2 HAProxy:"
    echo "  Public IP:  ${HAPROXY_DC2_PUBLIC}"
    echo "  Private IP: ${HAPROXY_DC2_PRIVATE}"
    echo "  Stats URL:  http://${HAPROXY_DC2_PUBLIC}:8404/stats"
    echo "  SSH:        ssh -i ~/.ssh/aap-dr-us-west-1.pem ec2-user@${HAPROXY_DC2_PUBLIC}"
else
    log_warning "DC2 HAProxy not found"
fi

# ===========================================
# Cost Estimation
# ===========================================
section_header "Monthly Cost Estimation"

log_info "Calculating approximate monthly costs..."

# Count running instances
DC1_RUNNING=$(aws ec2 describe-instances \
    --region "${DC1_REGION}" \
    --filters "Name=tag:Project,Values=${PROJECT_NAME}" "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text | wc -w | tr -d ' ')

DC2_RUNNING=$(aws ec2 describe-instances \
    --region "${DC2_REGION}" \
    --filters "Name=tag:Project,Values=${PROJECT_NAME}" "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text | wc -w | tr -d ' ')

echo "Running EC2 Instances:"
echo "  DC1: ${DC1_RUNNING} instances"
echo "  DC2: ${DC2_RUNNING} instances"
echo ""
echo "Estimated Monthly Costs (approximate):"
echo "  EC2 (DC1):          \$950/month"
echo "  EC2 (DC2):          \$120/month (HAProxy only)"
echo "  RDS Primary:        \$1,200/month"
echo "  RDS Replica:        \$600/month"
echo "  Data Transfer:      \$100/month"
echo "  EBS Storage:        \$50/month"
echo "  ─────────────────────────────────"
echo "  Total:              ~\$3,020/month"

# ===========================================
# Summary
# ===========================================
section_header "Infrastructure Summary"

echo "Environment Variables to Export:"
echo ""
if [[ -n "${RDS_DC1_ENDPOINT:-}" ]]; then
    echo "export RDS_DC1_ENDPOINT='${RDS_DC1_ENDPOINT}'"
fi
if [[ -n "${RDS_DC2_ENDPOINT:-}" ]]; then
    echo "export RDS_DC2_ENDPOINT='${RDS_DC2_ENDPOINT}'"
fi
echo ""

echo "Next Steps:"
echo ""
echo "1. Configure HAProxy:"
echo "   ansible-playbook configure-haproxy.yml -i inventory/aws_ec2.yml"
echo ""
echo "2. Install AAP on DC1 instances:"
echo "   ssh to each AAP component and run containerized installer"
echo ""
echo "3. Test connectivity:"
echo "   psql -h ${HAPROXY_DC1_PRIVATE:-HAPROXY_IP} -U postgres -d postgres"
echo ""
echo "4. Configure failover automation"
echo ""

log_success "Infrastructure information retrieval complete!"
