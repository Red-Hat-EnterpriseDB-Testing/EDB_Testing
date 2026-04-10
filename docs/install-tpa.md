# EDB PostgreSQL — Trusted Postgres Architect (TPA)

Deploy and manage PostgreSQL using **[Trusted Postgres Architect (TPA)](https://github.com/EnterpriseDB/tpa)**—EnterpriseDB’s open source (GPLv3) orchestration toolchain built on Ansible.

[← Back to main README](../README.md#installation) · [TPA documentation](https://www.enterprisedb.com/docs/tpa/latest/) · [OpenShift / operator path](install-kubernetes-manual.md) (separate from TPA)

<a id="rhel-tpa-ansible"></a>

## RHEL entry: Ansible on the control host (TPA)

Use **[TPA](https://github.com/EnterpriseDB/tpa)** on a **control node** to configure, provision, and deploy PostgreSQL on **RHEL** (or another [TPA-supported distribution](https://www.enterprisedb.com/docs/tpa/latest/reference/distributions/)) using EDB’s recommended practices. Follow **§ Quick start** below for `tpaexec configure`, `provision`, and `deploy`, and the **[official TPA documentation](https://www.enterprisedb.com/docs/tpa/latest/)** for topology and flags.

This repository **removed** a previously bundled `edb.postgres_operations` Ansible collection; use **TPA** (or your own playbooks) for host-based PostgreSQL automation.

## When to use TPA

TPA is the **supported EDB approach** for defining, provisioning, and deploying PostgreSQL clusters on infrastructure it drives: **bare metal**, **cloud instances (AWS, Azure, …)**, **`tpaexec`/SSH targets**, and **[Docker](https://www.enterprisedb.com/docs/tpa/latest/platform-docker/)** for lab-style testing (not production).

TPA does **not** replace **EDB PostgreSQL on OpenShift**: operator install, `Cluster` CRs, and cross-cluster replica topologies stay on the [manual OpenShift guide](install-kubernetes-manual.md) and [EDB PostgreSQL on OpenShift (operator documentation)](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/). If you need PostgreSQL **inside** the cluster as pods, use the operator; if you need PostgreSQL **on VMs or hosts** that front your platform, use TPA (or manual RHEL install).

## Quick start

1. **Clone TPA** (or install per [open source TPA](https://www.enterprisedb.com/docs/tpa/latest/opensourcetpa/)):

   ```bash
   git clone https://github.com/EnterpriseDB/tpa.git
   cd tpa
   ```

2. **Install dependencies** for the control host as described in TPA’s docs (Python, Ansible, etc.).

3. **Configure a cluster** (platform and topology depend on your environment). Typical flow:

   ```bash
   tpaexec configure mycluster --platform <bare|docker|...> [...]
   tpaexec provision mycluster
   tpaexec deploy mycluster
   ```

   Exact flags (HA, PGD, EDB PostgreSQL Advanced, location of instances) are covered in the **[official TPA documentation](https://www.enterprisedb.com/docs/tpa/latest/)**.

## Active / passive and multi-site

For standby replicas, witness nodes, and multi-datacenter patterns, use the **architecture and cluster options** documented in TPA (for example PGD or physical replicas, depending on product and version). Align that design with this repo’s high-level [README](../README.md) network and DR narrative for AAP.

## Ansible Automation Platform

TPA ships **execution-environment** material under its own repo (for example `tpa-ee/` paths in [EnterpriseDB/tpa](https://github.com/EnterpriseDB/tpa)). Use that for AAP job templates that run `tpaexec` or TPA playbooks.

