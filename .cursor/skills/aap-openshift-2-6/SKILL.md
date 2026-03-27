---
name: aap-openshift-2-6
description: >-
  Summarizes Red Hat Ansible Automation Platform 2.6 operator deployment on OpenShift (AnsibleAutomationPlatform CR, platform gateway, external PostgreSQL for gateway/controller/hub/EDA, channels, CSRF, idle_aap). Use when installing or configuring AAP on OpenShift, AAP operator custom resources, external Postgres, Event-Driven Ansible, or automation hub with the 2.6 operator.
---

# Ansible Automation Platform 2.6 on OpenShift (operator)

Authoritative source: [Installing on OpenShift Container Platform — Red Hat Ansible Automation Platform 2.6](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html-single/installing_on_openshift_container_platform/index). Prefer that guide over this skill for procedure text, screenshots, and version-specific errata.

## Scope

- Ground answers in **AAP 2.6** operator on **OpenShift** unless the user specifies another version or target (KVM, VMware, etc.).
- In **2.6**, the **platform gateway** is the unified UI; components are managed through a parent **`AnsibleAutomationPlatform`** custom resource (CR).

## Planning checklist

1. **Parent CR required**: After installing the operator, create an **`AnsibleAutomationPlatform`** CR—even if `AutomationController`, `AutomationHub`, or EDA objects already exist. Existing components must be registered via matching **`spec.controller.name`**, **`spec.hub.name`**, **`spec.eda.name`** in the **same namespace** as those CRs.
2. **Namespace**: Do not deploy AAP in **`default`**. Docs recommend **`ansible-automation-platform`** or **`aap`**; use a namespace that runs **only** AAP workloads.
3. **Operator channel** (Subscription):
   - **`stable-2.6`**: namespace-scoped operator (typical).
   - **`stable-2.6-cluster-scoped`**: manages AAP CRs across namespaces; needs broader permissions.
   - **Do not** switch between normal and cluster-scoped channels on the same install.
4. **OpenShift**: AAP 2.6 operator is documented for **OpenShift 4.12 through 4.17** and later—confirm current matrix in the same guide if the cluster version is edge.
5. **Storage**: Automation Hub needs **ReadWriteMany** file storage (or S3/Azure per docs), independent of Postgres placement.

## External PostgreSQL (single server, multiple databases)

One external PostgreSQL **instance** may back gateway, controller, hub, and EDA **if each component uses a different database name** on that instance.

| Component | Where to reference the secret on `AnsibleAutomationPlatform` |
|-----------|----------------------------------------------------------------|
| Platform gateway (shared platform DB) | `spec.database.database_secret` |
| Automation controller | `spec.controller.postgres_configuration_secret` |
| Automation hub | `spec.hub.postgres_configuration_secret` |
| Event-Driven Ansible | `spec.eda.database.database_secret` |

**PostgreSQL versions**: Managed DB shipped with the operator uses **PostgreSQL 15**. **External** databases support **15, 16, and 17**; for 16/17 you rely on **external** backup/restore processes (not the operator-managed Postgres backup story).

**Secret (`type: unmanaged`)**: Use **`stringData`** with at least **`host`**, **`port`**, **`database`**, **`username`**, **`password`**, **`type: "unmanaged"`**. For controller/hub, **`sslmode`** is valid for external DBs (`prefer`, `disable`, `allow`, `require`, `verify-ca`, `verify-full`). **Password must not** contain single quote, double quote, or backslash (docs warn this breaks deploy/backup/restore).

**Automation Hub on external Postgres**: Enable the **`hstore`** extension on the Hub database **before** install (migrations assume it; managed Postgres does this automatically).

**Optional_TLS**: If automation controller must trust a private CA, use **`bundle_cacert_secret`** on the `AnsibleAutomationPlatform` CR (secret containing **`bundle-ca.crt`**).

For copy-paste YAML skeletons, see [reference.md](reference.md).

## Configuration discovery

- Parent CR: `oc explain ansibleautomationplatform.spec`
- Nested examples: `oc explain ansibleautomationplatform.spec.controller.postgres_configuration_secret`
- Full tree: `oc explain ansibleautomationplatform.spec.controller --recursive` (repeat for `hub`, `eda`)

Prefer editing the **AnsibleAutomationPlatform** CR so the operator propagates settings. When **removing** parameters, clear them from **both** the parent CR and any nested component CR if the operator created overrides.

## Platform gateway / CSRF / ingress

- Operator creates **Routes** and CSRF defaults for OpenShift Routes.
- **External ingress** (non-Route): configure **`CSRF_TRUSTED_ORIGINS`** (and related gateway settings) per **Configuring your CSRF settings for your platform gateway operator ingress** in the same guide.
- **Controller UI “CSRF” settings** in 2.6 **do not** drive platform gateway CSRF behavior (gateway is separate).

## Scaling and DR-friendly idle

- To scale **down** controller, hub, gateway, EDA workloads together: set **`idle_aap: true`** under **`spec`** on the **`AnsibleAutomationPlatform`** CR; set **`false`** to bring services back.
- For upgrades/migrations, follow the guide’s backup CRs (**AutomationControllerBackup**, **AutomationHubBackup**, **EDABackup**) and release notes.

## Common pitfalls (from product docs)

- **DateStyle / timestamptz**: External DBs with non-ISO `DateStyle` (e.g. Redwood) can break parsing; docs describe setting `datestyle = 'iso, mdy'` and reloading Postgres.
- **PVCs**: Deleting an `AutomationController` or `AutomationHub` CR **does not** delete PVCs—clean up stale claims before redeploying the same instance name.
- **Existing 2.4 external DB on upgrade**: May only need **`spec.database.database_secret`** while other components keep prior DBs until migrated—see **aap-configuring-existing-external-db-all-default-components** in the guide appendix.

## When unsure

1. Cite or follow the linked **Installing on OpenShift Container Platform 2.6** chapter that matches the task (external DB, Hub storage, EDA, Lightspeed, MCP, upgrade).
2. Use **`oc explain`** on the live cluster for field names—CRDs can add fields in newer z-streams.

## Further detail

- [reference.md](reference.md) — Minimal `AnsibleAutomationPlatform` external-DB layout and secret keys.
