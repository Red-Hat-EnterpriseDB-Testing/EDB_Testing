# EDB Postgres on RHEL — Ansible Installation

Install EDB Postgres on RHEL using the `edb.postgres_operations` Ansible collection. The playbook runs the **install_postgres_rhel** role, which installs the EDB repository, PostgreSQL (or PGD) packages, configures `postgresql.conf` and `pg_hba.conf`, opens the firewall, and creates an application user and database.

[← Back to main README](../README.md#installation) · [Manual installation](install-rhel-manual.md)

## Prerequisites

- **RHEL 8 or 9** target host(s) with root or sudo access
- **Ansible 2.14+** on the control node
- **EDB repository access** (valid EDB subscription)
- **Minimum resources** on target: 4 CPU cores, 16 GB RAM, 50 GB disk (increase for production)

## Requirements

- `edb.postgres_operations` collection
- `community.postgresql` and `ansible.posix` (installed with the collection or via `ansible-galaxy collection install -r requirements.yml`)

## 1. Install the collection and dependencies

```bash
# From project root
ansible-galaxy collection install -r ansible_collections/edb/postgres_operations/requirements.yml
ansible-galaxy collection install ./ansible_collections/edb/postgres_operations
```

## 2. Create an inventory

Create an inventory with a `postgres_servers` group targeting your RHEL host(s):

```ini
[postgres_servers]
db01.example.com
db02.example.com
```

Use group or host vars for `postgres_version`, `app_database`, `app_owner`, `app_password`, etc., or pass them with `-e`.

## 3. Run the playbook

From the project root:

```bash
# Basic run
ansible-playbook -i <your-inventory> ansible_collections/edb/postgres_operations/playbooks/install-postgres-rhel.yml

# With PGD and app password (use -e or vault in production)
ansible-playbook -i <your-inventory> ansible_collections/edb/postgres_operations/playbooks/install-postgres-rhel.yml \
  -e "install_pgd=true" \
  -e "app_password=YourSecurePassword"

# With Ansible Vault for app_password
ansible-playbook -i <your-inventory> ansible_collections/edb/postgres_operations/playbooks/install-postgres-rhel.yml --ask-vault-pass -e @group_vars/postgres_servers/vault.yml
```

## Variables

Override with `-e` or group/host vars:

| Variable | Default | Description |
|----------|---------|-------------|
| `postgres_version` | `16` | PostgreSQL major version |
| `install_pgd` | `false` | Install EDB Postgres Distributed |
| `app_database` | — | Application database name |
| `app_owner` | — | Application database owner |
| `app_password` | — | Application user password |
| `pg_hba_cidr` | — | CIDR for pg_hba.conf |
| `pg_port` | — | PostgreSQL port |
| `firewall_enabled` | — | Open firewall for PostgreSQL |

Full list and role details: [install_postgres_rhel role](../ansible_collections/edb/postgres_operations/roles/install_postgres_rhel/README.md).

## Next steps

- **Collection docs**: [GETTING_STARTED](../ansible_collections/edb/postgres_operations/docs/GETTING_STARTED.md), [README](../ansible_collections/edb/postgres_operations/README.md)
- **Manual install / PGD**: [RHEL manual installation](install-rhel-manual.md)
