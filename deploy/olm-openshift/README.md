# OpenShift OLM install (optional)

Use this folder when installing **EDB Postgres® AI for CloudNativePG™ Cluster** from **OperatorHub** with `oc` / `kubectl`, instead of the manifest bundle under [`../operator`](../operator).

Official steps and context: [Red Hat OpenShift — Installation via the oc CLI](https://www.enterprisedb.com/docs/postgres_for_kubernetes/latest/openshift/#installation-via-the-oc-cli).

## Prerequisites

- Account with permissions to create `Subscription` objects (typically **cluster-admin** for cluster-wide installs).
- Access to **certified-operators** on your cluster (`openshift-marketplace` CatalogSource present).
- EDB subscription token for **docker.enterprisedb.com** when using private operator/operand images.

## 1. Confirm the package is available

```bash
oc get packagemanifests -n openshift-marketplace cloud-native-postgresql
oc describe packagemanifests -n openshift-marketplace cloud-native-postgresql
```

## 2. Create the EDB pull secret (openshift-operators)

For OperatorHub installs, EDB documents a docker-registry secret in **`openshift-operators`** named **`postgresql-operator-pull-secret`** (user **`k8s`**, password your token). See the same OpenShift page under *Installation via web console* / pull secret.

```bash
oc create secret docker-registry postgresql-operator-pull-secret \
  -n openshift-operators \
  --docker-server=docker.enterprisedb.com \
  --docker-username=k8s \
  --docker-password='REPLACE_WITH_TOKEN'
```

If the `Subscription` already exists, patch the operator’s service account or CSV defaults if your environment requires linking this secret (follow your cluster/EDB support guidance if pulls still fail).

## 3. Cluster-wide install (default)

Uses the default **global** `OperatorGroup` in `openshift-operators`—only the `Subscription` is applied:

```bash
oc apply -k deploy/olm-openshift
```

Then watch the install:

```bash
oc get csv -n openshift-operators -w
oc get pods -n openshift-operators -l name=postgresql-operator-manager
```

## 4. Multi-namespace (or single-namespace) example

Do **not** apply the kustomization in this folder if you use a dedicated `OperatorGroup`. Edit **`operatorgroup-multinamespace.example.yaml`** (namespaces, channel if you pin to `stable` / `stable-vX.Y`), create **`my-operators`** and target projects, then:

```bash
oc apply -f deploy/olm-openshift/operatorgroup-multinamespace.example.yaml
```

## 5. Sample `Cluster` workload

After the operator CSV is **Succeeded**, apply the demo database from [`../sample-cluster`](../sample-cluster) (image and pull secrets per your license/registry choice).

## Upgrades

EDB requires the **unified** registry path (`docker.enterprisedb.com/k8s`) before operator upgrades if you are migrating from older repository layouts. See EDB’s registry migration documentation linked from the OpenShift install page.
