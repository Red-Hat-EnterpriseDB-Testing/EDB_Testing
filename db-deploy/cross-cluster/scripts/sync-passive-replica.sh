#!/usr/bin/env bash
# Create a Route on the primary OpenShift, copy CNPG replication TLS Secrets to a second cluster, and apply
# a passive streaming replica Cluster (EDB Postgres for Kubernetes / CloudNativePG).
#
# Requires: oc, jq, python3; healthy primary Cluster; operator on both clusters; network path from replica
# nodes to the Route hostname (often :443 for passthrough routes).
#
# You MUST set PRIMARY_CONTEXT and REPLICA_CONTEXT so each oc invocation targets the correct API server.
# Kubeconfig defaults are generic; override with PRIMARY_KUBECONFIG / REPLICA_KUBECONFIG if you use split files.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

PRIMARY_KUBECONFIG="${PRIMARY_KUBECONFIG:-${KUBECONFIG:-$HOME/.kube/config}}"
REPLICA_KUBECONFIG="${REPLICA_KUBECONFIG:-${KUBECONFIG:-$HOME/.kube/config}}"
: "${PRIMARY_CONTEXT:?Set PRIMARY_CONTEXT to the context name for the primary OpenShift cluster (oc config get-contexts)}"
: "${REPLICA_CONTEXT:?Set REPLICA_CONTEXT to the context name for the replica OpenShift/Kubernetes cluster}"

NS="${NS:-edb-postgres}"
PRIMARY_CLUSTER_NAME="${PRIMARY_CLUSTER_NAME:-postgresql}"
REPLICA_CLUSTER_NAME="${REPLICA_CLUSTER_NAME:-postgresql-replica}"
# Must match metadata.name in cross-cluster/primary-site/route-replication.yaml unless you templating the Route.
ROUTE_NAME="${ROUTE_NAME:-postgresql-replication}"
SECRET_REPLICATION="${PRIMARY_CLUSTER_NAME}-replication"
SECRET_CA="${PRIMARY_CLUSTER_NAME}-ca"

primary_oc() { oc --kubeconfig "$PRIMARY_KUBECONFIG" --context "$PRIMARY_CONTEXT" "$@"; }
replica_oc() { oc --kubeconfig "$REPLICA_KUBECONFIG" --context "$REPLICA_CONTEXT" "$@"; }

sanitize_secret() {
  jq 'del(
    .metadata.uid,
    .metadata.resourceVersion,
    .metadata.creationTimestamp,
    .metadata.managedFields,
    .metadata.ownerReferences
  ) | .metadata.namespace = "'"$NS"'"'
}

if [[ ! -f "$REPO_ROOT/cross-cluster/primary-site/route-replication.yaml" ]]; then
  echo "error: expected $REPO_ROOT/cross-cluster/primary-site/route-replication.yaml" >&2
  exit 1
fi

echo "Applying replication Route on primary cluster (namespace $NS)..."
primary_oc apply -f "$REPO_ROOT/cross-cluster/primary-site/route-replication.yaml"

PRIMARY_REPLICATION_HOST="$(primary_oc -n "$NS" get route "$ROUTE_NAME" -o jsonpath='{.spec.host}' 2>/dev/null || true)"
if [[ -z "$PRIMARY_REPLICATION_HOST" ]]; then
  echo "error: could not read route host for $ROUTE_NAME in namespace $NS (check ROUTE_NAME vs Route metadata.name)" >&2
  exit 1
fi
export PRIMARY_REPLICATION_HOST
echo "Primary replication endpoint (Route host): $PRIMARY_REPLICATION_HOST (typical TLS port in connection string: 443)"

echo "Syncing TLS secrets $NS/$SECRET_REPLICATION and $SECRET_CA from primary -> replica cluster..."
for sec in "$SECRET_REPLICATION" "$SECRET_CA"; do
  primary_oc get secret "$sec" -n "$NS" -o json | sanitize_secret | replica_oc apply -f -
done

echo "Applying app credentials secret on replica cluster (align password with primary before promotion workflows)..."
replica_oc apply -f "$REPO_ROOT/sample-cluster/base/app-db-credentials.secret.yaml"

delete_cluster_wait() {
  local name="$1"
  if replica_oc get cluster "$name" -n "$NS" &>/dev/null; then
    echo "Deleting Cluster $name in $NS on replica site..."
    replica_oc delete cluster "$name" -n "$NS" --wait=false
    for _ in $(seq 1 60); do
      if ! replica_oc get cluster "$name" -n "$NS" &>/dev/null; then
        break
      fi
      sleep 5
    done
    replica_oc delete pvc -n "$NS" -l "cnpg.io/cluster=$name" --ignore-not-found=true || true
  fi
}

# Remove a mistaken standalone primary on the replica cluster, if present
if replica_oc get cluster "$PRIMARY_CLUSTER_NAME" -n "$NS" &>/dev/null; then
  echo "Deleting standalone $PRIMARY_CLUSTER_NAME on replica site (replaced by $REPLICA_CLUSTER_NAME)..."
  delete_cluster_wait "$PRIMARY_CLUSTER_NAME"
fi

delete_cluster_wait "$REPLICA_CLUSTER_NAME"

echo "Creating passive replica Cluster $REPLICA_CLUSTER_NAME..."
export REPO_ROOT_FOR_PY="$REPO_ROOT"
export REPLICA_CLUSTER_NAME
python3 <<'PY' | replica_oc apply -f -
import os, pathlib, re

host = os.environ["PRIMARY_REPLICATION_HOST"]
name = os.environ["REPLICA_CLUSTER_NAME"]
root = pathlib.Path(os.environ["REPO_ROOT_FOR_PY"])
path = root / "cross-cluster/replica-site/replica-cluster.template.yaml"
text = path.read_text()
placeholder = "${PRIMARY_REPLICATION_HOST}"
if placeholder not in text:
    raise SystemExit(f"template missing {placeholder}")
text = text.replace(placeholder, host)
text = re.sub(r"(?m)^  name: postgresql-replica$", f"  name: {name}", text, count=1)
print(text)
PY

echo "Done. Watch: oc --kubeconfig \"\$REPLICA_KUBECONFIG\" --context \"\$REPLICA_CONTEXT\" get cluster,pods -n $NS -w"
