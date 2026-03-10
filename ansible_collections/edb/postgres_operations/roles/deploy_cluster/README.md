# Role: deploy_cluster

Deploy EnterpriseDB Postgres for Kubernetes clusters on OpenShift.

## Description

This role automates the deployment of PostgreSQL clusters using the EDB Postgres for Kubernetes operator. It handles namespace creation, secret management, cluster configuration, and monitoring setup.

## Requirements

- Ansible 2.14+
- `kubernetes.core` collection
- `community.postgresql` collection
- Valid kubeconfig for target OpenShift cluster
- EDB subscription credentials and pull secret (see below)

## EDB Pull Secret

The role pulls PostgreSQL images from EDB’s private registry (`docker.enterprisedb.com`). You must provide a Kubernetes pull secret (or a Docker config file the role can turn into one).

### 1. Get your EDB account token

- Access requires an EDB account and a valid [subscription plan](https://www.enterprisedb.com/products/plans-comparison#selfmanagedenterpriseplan).
- Get your **EDB account token** from the [EDB portal: Get your token](https://www.enterprisedb.com/docs/repos/getting_started/with_web/get_your_token/).
- Store it in an environment variable, e.g. `EDB_SUBSCRIPTION_TOKEN`.

### 2. Create a Docker config file for the role

The role uses `edb_pull_secret_file` to read a Docker config JSON and create a `kubernetes.io/dockerconfigjson` secret. Create that file as follows.

**Option A – using Docker login (recommended)**

```bash
# Log in to EDB registry (writes ~/.docker/config.json)
docker login docker.enterprisedb.com \
  --username k8s \
  --password-stdin <<< "$EDB_SUBSCRIPTION_TOKEN"

# Copy only the EDB registry entry to a file for the role
# Create secrets/ (or your chosen path) and then:
jq '{"auths": {"docker.enterprisedb.com": .auths["docker.enterprisedb.com"]}}' \
  ~/.docker/config.json > secrets/edb-dockerconfig.json
```

**Option B – create the JSON manually**

Create `secrets/edb-dockerconfig.json` with:

```json
{
  "auths": {
    "docker.enterprisedb.com": {
      "username": "k8s",
      "password": "YOUR_EDB_ACCOUNT_TOKEN",
      "auth": "<base64 of 'k8s:YOUR_EDB_ACCOUNT_TOKEN'>"
    }
  }
}
```

Replace `YOUR_EDB_ACCOUNT_TOKEN` with your token. The `auth` field is the Base64 encoding of `k8s:<token>` (e.g. `echo -n "k8s:YOUR_TOKEN" | base64`).

### 3. Use the file in the role

- Set `edb_pull_secret_file` to the path of that JSON (default: `secrets/edb-dockerconfig.json`).
- Optionally set `edb_pull_secret_name` if you want a different Kubernetes secret name (default: `edb-pull-secret`).
- Keep the JSON out of version control (e.g. add `secrets/` to `.gitignore`) and use Ansible Vault or a secrets manager for automation.

**Reference:** [EDB private container registry](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/private_edb_registries/)

## Role Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `cluster_name` | Name of the PostgreSQL cluster | `prod-db` |
| `namespace` | Kubernetes namespace | `production` |
| `kubeconfig_path` | Path to kubeconfig file | `~/.kube/config` |
| `datacenter` | Datacenter identifier | `dc1` |

### Optional Variables (with defaults)

| Variable | Default | Description |
|----------|---------|-------------|
| `instances` | `3` | Number of PostgreSQL instances |
| `postgres_version` | `16.8` | PostgreSQL version |
| `storage_size` | `10Gi` | Storage size for data |
| `storage_class` | `local-path` | Storage class name |
| `monitoring_enabled` | `true` | Enable monitoring |
| `edb_pull_secret_name` | `edb-pull-secret` | Kubernetes secret name for the EDB registry pull secret |
| `edb_pull_secret_file` | `secrets/edb-dockerconfig.json` | Path to Docker config JSON for EDB registry (see [EDB Pull Secret](#edb-pull-secret)) |

See [defaults/main.yml](defaults/main.yml) for all available variables.

## Dependencies

None.

## Example Playbook

```yaml
- hosts: openshift_clusters
  roles:
    - role: edb.postgres_operations.deploy_cluster
      vars:
        cluster_name: prod-db
        namespace: production
        instances: 5
        storage_size: 100Gi
```

## Example Usage with Extra Vars

```bash
ansible-playbook playbook.yml \
  -e "cluster_name=prod-db" \
  -e "namespace=production" \
  -e "instances=5"
```

## Output

The role sets the following facts:

- `cluster_primary` - Name of the primary pod
- `cluster_phase` - Current cluster phase
- `cluster_instances` - Total number of instances
- `cluster_ready_instances` - Number of ready instances
- `cluster_rw_service` - Read-write service endpoint
- `cluster_ro_service` - Read-only service endpoint

## License

Apache-2.0

## Author

EDB Engineering Team
