# EDB Postgres on RHEL — TPA (recommended)

Use **[Trusted Postgres Architect (TPA)](https://github.com/EnterpriseDB/tpa)** on the control node to configure, provision, and deploy PostgreSQL on RHEL (or other [supported distributions](https://www.enterprisedb.com/docs/tpa/latest/reference/distributions/)) according to EDB’s practices.

[← Back to main README](../README.md#installation) · **[Full TPA guide for this repo](install-tpa.md)** · [Manual RHEL install (no TPA)](install-rhel-manual.md)

## Steps

See **[docs/install-tpa.md](install-tpa.md)** for clone links, `tpaexec configure` / `provision` / `deploy`, and pointers to [EDB TPA documentation](https://www.enterprisedb.com/docs/tpa/latest/).

The project previously vendored an `edb.postgres_operations` collection; it has been **removed** from this repository in favor of TPA.
