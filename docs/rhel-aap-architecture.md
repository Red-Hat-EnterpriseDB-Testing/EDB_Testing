# RHEL — Ansible Automation Platform (AAP) architecture

This page summarizes **AAP on RHEL** (systemd-based) in this repository’s reference design: multi-datacenter posture, service dependencies, and how that differs from OpenShift.

[← Main README — AAP section](../README.md#ansible-automation-platform-aap) · [AAP scripts](../scripts/README.md) · [Short runbook](manual-scripts-doc.md)

## Topology (summary)

- AAP components run as **systemd units** (controller, hub, nginx, redis, receptor, and optionally local PostgreSQL if not externalized).
- For **two datacenters** on RHEL, the same logical **active / passive** rule applies as on OpenShift: you **must not** run full active AAP stacks against the same read-write database. **Turn off services on the secondary site** when the primary site is live, unless you are executing a tested DR runbook.
- You will do a single install across datacenters and stop the services on the secondary site and point the load balancer to site 1 only.

## Service order and lifecycle

- **Start / stop scripts** (orderly bring-up or shutdown): `**[scripts/start-aap-cluster.sh](../scripts/start-aap-cluster.sh)`**, `**[scripts/stop-aap-cluster.sh](../scripts/stop-aap-cluster.sh)**` — described in `**[scripts/README.md](../scripts/README.md)**`.
- Example systemd wrapper: `**[scripts/aap-cluster.service](../scripts/aap-cluster.service)**`.

## Postgres on RHEL

- **Recommended automation** for PostgreSQL on hosts: **[Trusted Postgres Architect (TPA)](install-tpa.md)** ([upstream](https://github.com/EnterpriseDB/tpa)).
- **Manual install** (no TPA): `**[docs/install-rhel-manual.md](install-rhel-manual.md)`**.

## Failover and DR

- EDB **Enterprise Failover Manager (EFM)** integration and AAP hooks: `**[docs/enterprisefailovermanager.md](enterprisefailovermanager.md)`** · scripts under `**scripts/efm-*.sh**`.

For product install specifics (packages, inventory, license), use **Red Hat AAP installation documentation** for your version.