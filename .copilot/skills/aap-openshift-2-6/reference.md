# AAP 2.6 on OpenShift — reference snippets

Source: [Installing on OpenShift Container Platform — AAP 2.6](https://docs.redhat.com/en/documentation/red_hat_ansible_automation_platform/2.6/html-single/installing_on_openshift_container_platform/index) (Appendix: custom resources, Chapter 5 external database sections).

These are structural examples only—adjust names, namespaces, and storage classes to the environment.

## External Postgres secrets (four logical databases, one server)

Use **different** `database:` values in each secret when sharing one PostgreSQL instance.

**Gateway (platform) secret** — referenced by `spec.database.database_secret`:

- Keys follow the gateway external-DB procedure in the guide (same unmanaged connection pattern).

**Controller / Hub secrets** — `postgres_configuration_secret`; include `sslmode` when using TLS.

**EDA secret** — nested as `spec.eda.database.database_secret` in the full-platform example below.

## AnsibleAutomationPlatform: all default components on external Postgres

Matches appendix pattern **`aap-configuring-external-db-all-default-components.yml`** (names are illustrative):

```yaml
apiVersion: aap.ansible.com/v1alpha1
kind: AnsibleAutomationPlatform
metadata:
  name: myaap
  namespace: ansible-automation-platform
spec:
  database:
    database_secret: external-postgres-configuration-gateway
  controller:
    postgres_configuration_secret: external-postgres-configuration-controller
  hub:
    postgres_configuration_secret: external-postgres-configuration-hub
    storage_type: file
    file_storage_storage_class: <read-write-many-storage-class>
    file_storage_size: 10Gi
  eda:
    database:
      database_secret: external-postgres-configuration-eda
```

Hub still requires **content** storage (RWX file, S3, or Azure) even when Postgres is external.

## Controller external Postgres secret (minimal shape)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: external-postgres-configuration-controller
  namespace: ansible-automation-platform
type: Opaque
stringData:
  host: "<dns-or-ip-reachable-from-cluster>"
  port: "5432"
  database: "<controller-db-name>"
  username: "<user>"
  password: "<password-without-quotes-or-backslashes>"
  sslmode: "prefer"
  type: "unmanaged"
```

## Lightspeed with external DB (optional)

If **Ansible Lightspeed** is enabled and uses an external DB, the guide shows an additional `lightspeed.database.database_secret` alongside auth/model secrets. See **`aap-configuring-external-db-with-lightspeed-enabled.yml`** in the appendix and the Lightspeed chapters.

## Subscription channel example (CLI)

The guide uses **`channel: 'stable-2.6'`** with `name: ansible-automation-platform-operator` and `source: redhat-operators` / `openshift-marketplace`. Verify the exact channel string in OperatorHub for your cluster date.
