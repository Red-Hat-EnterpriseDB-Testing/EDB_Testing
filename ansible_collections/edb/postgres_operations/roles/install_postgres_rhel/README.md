# Role: install_postgres_rhel

Install EDB Postgres on RHEL systems (repository, PostgreSQL or PGD packages, configuration, firewall, application user and database).

## Requirements

- Ansible 2.14+
- `community.postgresql` and `ansible.posix` collections

## Role Variables

See [defaults/main.yml](defaults/main.yml). Key variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `postgres_version` | `16` | PostgreSQL major version |
| `install_pgd` | `false` | Install EDB Postgres Distributed (PGD) |
| `app_database` | `app_db` | Application database name |
| `app_owner` | `app_user` | Application role name |
| `app_password` | `change_me` | Application role password (override with vault) |
| `pg_hba_cidr` | `10.0.0.0/8` | CIDR for pg_hba.conf host rule |
| `firewall_enabled` | `true` | Open firewall port for PostgreSQL |

## Example Playbook

```yaml
- hosts: postgres_servers
  become: true
  roles:
    - role: edb.postgres_operations.install_postgres_rhel
      vars:
        postgres_version: "16"
        install_pgd: false
        app_password: "{{ vault_app_password }}"
```

## License

Apache-2.0
