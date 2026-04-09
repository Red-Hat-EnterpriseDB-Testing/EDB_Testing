# AAP cluster management — runbook

Operational notes for **starting, stopping, and scaling** Ansible Automation Platform in **RHEL (systemd)** and **OpenShift** environments. Authoritative command usage and script behavior live in **[`scripts/README.md`](../scripts/README.md)**; this page only captures **when** and **in what order** to act.

[← Main README — AAP cluster management](../README.md#aap-cluster-management) · [EFM integration](enterprisefailovermanager.md) · [Scripts directory](../scripts/)

## OpenShift — standby site (scale to zero)

Use when the **passive** datacenter should not run AAP pods (save resources, avoid split-brain against the database):

- **`scripts/scale-aap-down.sh`** — scale AAP deployments to **0** replicas (see `scripts/README.md` for context flag).
- **`scripts/scale-aap-up.sh`** — restore target replica counts when failing **into** that site or for testing.

**Caution:** Coordinate with **database role** (single RW primary). Do not run two live controllers against one primary without a validated DR design.

## RHEL — start / stop stack

- **`scripts/start-aap-cluster.sh`** — start dependencies then AAP services in order (copy path per `scripts/README.md` if installing under `/usr/local/bin`).
- **`scripts/stop-aap-cluster.sh`** — reverse order shutdown for maintenance or DR rehearsal.

## EFM-driven failover (PostgreSQL promotion)

When PostgreSQL failover is handled by **EDB Failover Manager** and you must **raise AAP** in the datacenter that now holds the primary:

- Wrapper / orchestration: **`scripts/efm-aap-failover-wrapper.sh`**, **`scripts/efm-orchestrated-failover.sh`**
- **Read first:** [`enterprisefailovermanager.md`](enterprisefailovermanager.md) and **`scripts/efm.properties.sample`**

## Monitoring hooks

- **`scripts/monitor-efm-scripts.sh`** — optional health / notification helper (details in `scripts/README.md`).

---

**Do not** maintain duplicate copies of script bodies in this document; edit **`scripts/*.sh`** and document behavior in **`scripts/README.md`**.
