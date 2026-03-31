# OpenShift — Ansible Automation Platform (AAP) architecture

This page summarizes how **AAP** is positioned on **OpenShift** in this repository’s reference design: multiple clusters, external EDB Postgres, and passive standby sites.

[← Main README — AAP section](../README.md#ansible-automation-platform-aap) · [Operator install (single cluster + external Postgres)](../aap-deploy/openshift/README.md) · [Two-site operator + DR plan](../aap-deploy/README.md)

## Topology (summary)

- **One AAP footprint per OpenShift cluster** you treat as a site (typical namespace: `ansible-automation-platform`).
- **Postgres for AAP workloads** can be the **EDB Postgres on OpenShift** `Cluster` (e.g. `postgresql` in namespace `edb-postgres`) or another supported external database per Red Hat guidance.
- **Active / passive between sites**: only one site should run production AAP against the **read-write** database primary; the other site keeps **workloads off** or scaled down until DR.

## Day-0 install (this repo)

- **Concrete steps** (subscription, SQL bootstrap, secrets, `AnsibleAutomationPlatform` CR): **[`aap-deploy/openshift/README.md`](../aap-deploy/openshift/README.md)**.
- **Wider HA/DR narrative** (two sites, replica secrets, EDA): **[`aap-deploy/README.md`](../aap-deploy/README.md)**.

## Postgres and networking

- In-cluster EDB clusters follow **EDB Postgres on OpenShift** CRDs (`postgresql.k8s.enterprisedb.io/v1`). See **[`docs/install-kubernetes-manual.md`](install-kubernetes-manual.md)** and **[`db-deploy/README.md`](../db-deploy/README.md)**.
- **Replication across clusters** (passive replica pattern): **[`db-deploy/cross-cluster/README.md`](../db-deploy/cross-cluster/README.md)**.

## Operations

- Scale AAP on the standby site: **[`scripts/README.md`](../scripts/README.md)** (e.g. `scale-aap-down.sh` / `scale-aap-up.sh`) and **[`docs/manual-scripts-doc.md`](manual-scripts-doc.md)** (short runbook).
- Failover orchestration with EDB **EFM** and custom hooks: **[`docs/enterprisefailovermanager.md`](enterprisefailovermanager.md)**.
- You must have the same execution nodes if you try and add different ones you will have conflict with mesh

Product-specific sizing, routes, and licensing remain in **Red Hat AAP 2.6 OpenShift documentation**.
