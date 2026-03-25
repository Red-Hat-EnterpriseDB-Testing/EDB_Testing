# EDB Postgres for Kubernetes / OpenShift — operator & manual automation

**EDB Postgres for Kubernetes** (operator + CRs) on OpenShift is installed and upgraded via the **operator** and **manual or GitOps manifests**, as in the manual guide. This repository does not ship a vendored Ansible collection for that path.

[← Back to main README](../README.md#installation) · **[Manual OpenShift / Kubernetes install](install-kubernetes-manual.md)**

## Recommended path

1. Install the **EDB Postgres for Kubernetes** operator (OperatorHub, CLI, or your supported install method)—see [Manual installation](install-kubernetes-manual.md#1-install-the-edb-postgres-for-openshift-operator).
2. Apply **`Cluster`** and related CRs (pull secrets, backups, replica clusters) per [EDB Postgres for Kubernetes documentation](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/).
3. For multi-cluster active/passive topologies (replica cluster, promotion tokens), follow the architecture sections in [install-kubernetes-manual.md](install-kubernetes-manual.md#edb-postgres-for-kubernetes-architecture) and the main [README](../README.md).

## Ansible and AAP without the in-repo collection

You may drive `kubernetes.core.k8s` / `oc` from **your own** playbooks or from **Ansible Validated / certified** content, using an execution environment that contains `kubernetes.core` and a valid kubeconfig.

## Trusted Postgres Architect (TPA)

**[TPA](https://github.com/EnterpriseDB/tpa)** provisions Postgres on **hosts** (VMs, bare metal, Docker for testing)—not as the Kubernetes operator workload. For Postgres **on OpenShift pods**, use the operator path above. For Postgres **on RHEL instances outside/around the cluster**, use **[install-tpa.md](install-tpa.md)**.

## Ansible Navigator and execution environments

For AAP or local runs, use an execution environment that matches **your** playbooks and collections, or TPA’s **`tpa-ee`** assets in the [TPA repository](https://github.com/EnterpriseDB/tpa/tree/main/tpa-ee).
