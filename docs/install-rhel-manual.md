# EDB PostgreSQL on RHEL — Manual Installation

This guide covers installing EDB PostgreSQL on RHEL manually (repository, packages, PGD, and post-install configuration) for traditional VM-based deployments.

[← Back to main README](../README.md#installation) · [TPA on RHEL (recommended)](install-tpa.md#rhel-tpa-ansible)

## Prerequisites

- **RHEL 9.4+** system with root or sudo access (required for AAP 2.6)
- **EDB Repository Access**: Valid EDB subscription credentials
- **Network Access**: Connection to EDB repositories
- **Minimum Resources**:
  - 4 CPU cores (8+ recommended for production)
  - 16 GB RAM (32+ GB recommended for production)
  - 50 GB disk space (200+ more for production databases)

## Installation Methods

### Using EDB repository (standard PostgreSQL/EPAS)

Install from the EDB repository:

```bash
# Add EDB repository
sudo dnf install -y https://yum.enterprisedb.com/edb-repo-rpms/edb-repo-latest.noarch.rpm

# Install PostgreSQL or EPAS (example: PostgreSQL 16)
sudo dnf install -y postgresql16-server
# Or for EPAS:
# sudo dnf install -y edb-as16-server

# Initialize and start (paths vary by product)
sudo postgresql-setup --initdb
sudo systemctl enable postgresql-16
sudo systemctl start postgresql-16
```

### Using EDB PostgreSQL Distributed (PGD)

For multi-datacenter replication scenarios, use EDB PostgreSQL Distributed:

```bash
# Install PGD repository
sudo dnf install -y https://yum.enterprisedb.com/edb-repo-rpms/edb-repo-latest.noarch.rpm

# Install PGD components
sudo dnf install -y edb-pgd5

# Install PostgreSQL if not already installed
sudo dnf install -y postgresql16-server

# Initialize and configure PGD
# Follow the detailed guide at:
# https://www.enterprisedb.com/docs/pgd/latest/overview/quickstart/
```

## Post-Installation Configuration

### 1. Configure PostgreSQL to listen on the network

```bash
# Edit postgresql.conf (path may vary: /var/lib/edb/as16/data/postgresql.conf or similar)
sudo vi /var/lib/edb/as16/data/postgresql.conf

# Update these settings:
listen_addresses = '*'
max_connections = 1500
shared_buffers = 256MB
```

### 2. Configure authentication

```bash
# Edit pg_hba.conf
sudo vi /var/lib/edb/as16/data/pg_hba.conf

# Add entries for your network (change to your CIDR):
host    all             all             10.0.0.0/8              scram-sha-256
host    all             all             192.168.0.0/16          scram-sha-256
```

### 3. Restart PostgreSQL

```bash
sudo systemctl restart edb-as-16
# Or: sudo systemctl restart postgresql-16
```

### 4. Create database users and databases

```sql
# Switch to postgres user
sudo su - enterprisedb

# Connect to PostgreSQL
psql

-- Create application user
CREATE ROLE app_user WITH LOGIN PASSWORD 'secure_password';

-- Create application database
CREATE DATABASE app_db OWNER app_user;

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE app_db TO app_user;
```

## Firewall configuration

```bash
# Allow PostgreSQL port (5432 or 5444 for EPAS)
sudo firewall-cmd --permanent --add-port=5432/tcp
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --list-all
```

## Quick start resources

- **EDB PostgreSQL Distributed Quickstart**: [https://www.enterprisedb.com/docs/pgd/latest/overview/quickstart/](https://www.enterprisedb.com/docs/pgd/latest/overview/quickstart/)
- **EDB Installation Guide**: [https://www.enterprisedb.com/docs/epas/latest/installing/](https://www.enterprisedb.com/docs/epas/latest/installing/)
