# EDB Postgres for Kubernetes / OpenShift — operator & manual automation

**EDB Postgres for Kubernetes** (operator + CRs) on OpenShift is installed and upgraded via the **operator** and **manual or GitOps manifests**, as in the manual guide. This repository does not ship a vendored Ansible collection for that path.

[← Back to main README](../README.md#installation) · **[Manual OpenShift / Kubernetes install](install-kubernetes-manual.md)** · **[Kustomize manifests in `db-deploy/`](../db-deploy/README.md)**

## Recommended path

1. Install the **EDB Postgres for Kubernetes** operator (OperatorHub, CLI, or your supported install method)—see [Manual installation](install-kubernetes-manual.md#1-install-the-edb-postgres-for-openshift-operator). This repository includes a Kustomize base that pulls the pinned manifest from `get.enterprisedb.io`: [**`db-deploy/operator`**](../db-deploy/README.md#install-operator) ([full `db-deploy/` layout](../db-deploy/README.md)).
2. Apply **`Cluster`** and related CRs (pull secrets, backups, replica clusters) per [EDB Postgres for Kubernetes documentation](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/). A minimal sample workload lives in [**`db-deploy/sample-cluster/`**](../db-deploy/README.md#apply-sample-cluster). For EDB registry images, create a `docker-registry` secret in the workload namespace and list it under `spec.imagePullSecrets` on the `Cluster`—see [Manual installation, section 2](install-kubernetes-manual.md#2-deploy-a-postgresql-cluster-manual).
3. For a **passive streaming replica** across two kube contexts (example script + manifests, placeholder names only), see [**`db-deploy/cross-cluster/README.md`**](../db-deploy/cross-cluster/README.md). For broader DR / promotion concepts, see [install-kubernetes-manual.md](install-kubernetes-manual.md#edb-postgres-for-kubernetes-architecture) and the main [README](../README.md).

## Ansible and AAP without the in-repo collection

You may drive `kubernetes.core.k8s` / `oc` from **your own** playbooks or from **Ansible Validated / certified** content, using an execution environment that contains `kubernetes.core` and a valid kubeconfig.

## Trusted Postgres Architect (TPA)

**[TPA](https://github.com/EnterpriseDB/tpa)** provisions Postgres on **hosts** (VMs, bare metal, Docker for testing)—not as the Kubernetes operator workload. For Postgres **on OpenShift pods**, use the operator path above. For Postgres **on RHEL instances outside/around the cluster**, use **[install-tpa.md](install-tpa.md)**.

## Ansible Navigator and execution environments

For AAP or local runs, use an execution environment that matches **your** playbooks and collections, or TPA’s **`tpa-ee`** assets in the [TPA repository](https://github.com/EnterpriseDB/tpa/tree/main/tpa-ee).
