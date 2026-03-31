#!/usr/bin/env bash
# Deploy AAP 2.6 operator + AnsibleAutomationPlatform on OpenShift (e.g. CRC / aap-lab)
# with external EDB Postgres for Kubernetes (sample defaults: namespace edb-postgres, cluster postgresql).
#
# Prerequisites:
#   - OpenShift API reachable (e.g. `crc start` for local CRC)
#   - EDB operator + healthy primary Cluster matching the namespace/name you pass
#   - A ReadWriteMany StorageClass for Automation Hub (set HUB_STORAGE_CLASS). CRC often has
#     only RWO; use a suitable class (NFS, ODF, etc.) or the install may fail on Hub PVC.
#
# Usage:
#   export AAP_DB_PASSWORD='your-strong-password'   # no ', ", or \ in the password
#   export HUB_STORAGE_CLASS='your-rwx-storageclass' # required on most clusters
#   ./deploy-aap-lab-external-pg.sh
#
# Optional env:
#   OC_CONTEXT          default: aap-operator/localhost:6443/system:admin
#   PG_NAMESPACE        default: edb-postgres
#   PG_CLUSTER_NAME     default: postgresql
#   PGHOST              default: <cluster>-rw.<namespace>.svc.cluster.local
#   AAP_NAMESPACE       default: ansible-automation-platform
#   SKIP_DB_BOOTSTRAP=1 skip CREATE ROLE/DATABASE/hstore (if already done)
#   SKIP_OPERATOR_APPLY=1 skip subscription/operator install
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
AAP_OPENSHIFT="$REPO_ROOT/aap-deploy/openshift"
SQL_FILE="$REPO_ROOT/aap-deploy/edb-bootstrap/create-aap-databases.sql"

if [[ ! -f "$SQL_FILE" ]]; then
  echo "error: repo layout unexpected; missing $SQL_FILE" >&2
  exit 1
fi

: "${AAP_DB_PASSWORD:?Set AAP_DB_PASSWORD (no single quote, double quote, or backslash)}"
: "${HUB_STORAGE_CLASS:?Set HUB_STORAGE_CLASS to a ReadWriteMany StorageClass (oc get storageclass)}"

CTX="${OC_CONTEXT:-aap-operator/localhost:6443/system:admin}"
PG_NS="${PG_NAMESPACE:-edb-postgres}"
PG_CLUSTER="${PG_CLUSTER_NAME:-postgresql}"
AAP_NS="${AAP_NAMESPACE:-ansible-automation-platform}"
PGHOST="${PGHOST:-${PG_CLUSTER}-rw.${PG_NS}.svc.cluster.local}"

oc_g() { oc --context "$CTX" "$@"; }

echo "==> Using context: $CTX"
oc_g whoami

if [[ "${SKIP_OPERATOR_APPLY:-}" != "1" ]]; then
  echo "==> Installing AAP operator (namespace + subscription)..."
  oc_g apply -k "$AAP_OPENSHIFT"
  echo "==> Waiting for operator CSV Succeeded (up to ~15m)..."
  for _ in $(seq 1 180); do
    phase="$(oc_g get csv -n "$AAP_NS" -o jsonpath='{.items[0].status.phase}' 2>/dev/null || true)"
    if [[ "$phase" == "Succeeded" ]]; then
      echo "CSV Succeeded."
      break
    fi
    printf '  CSV phase: %s\n' "${phase:-pending}"
    sleep 5
  done
  phase="$(oc_g get csv -n "$AAP_NS" -o jsonpath='{.items[0].status.phase}' 2>/dev/null || true)"
  if [[ "$phase" != "Succeeded" ]]; then
    echo "error: CSV not Succeeded (last phase=$phase). Check: oc --context $CTX get csv,sub -n $AAP_NS" >&2
    exit 1
  fi
else
  echo "==> Skipping operator apply (SKIP_OPERATOR_APPLY=1)"
fi

echo "==> Resolving Postgres primary pod in $PG_NS (cluster $PG_CLUSTER)..."
POD="$(
  oc_g get pods -n "$PG_NS" \
    -l "k8s.enterprisedb.io/cluster=${PG_CLUSTER},role=primary" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
)"
if [[ -z "$POD" ]]; then
  POD="$(
    oc_g get pods -n "$PG_NS" \
      -l "k8s.enterprisedb.io/cluster=${PG_CLUSTER}" \
      --sort-by=.metadata.creationTimestamp \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
  )"
fi
if [[ -z "$POD" ]]; then
  echo "error: no pod found for cluster $PG_CLUSTER in $PG_NS" >&2
  exit 1
fi
echo "    Primary pod: $POD"

if [[ "${SKIP_DB_BOOTSTRAP:-}" != "1" ]]; then
  echo "==> Bootstrapping AAP databases (role + DBs + hstore)..."
  export AAP_DB_PASSWORD
  export SQL_FILE
  python3 <<'PY' | oc_g exec -i -n "$PG_NS" "$POD" -- psql -U postgres -v ON_ERROR_STOP=1 -f -
import os
import sys
path = os.environ["SQL_FILE"]
text = open(path, encoding="utf-8").read()
text = text.replace("REPLACE_WITH_STRONG_PASSWORD", os.environ["AAP_DB_PASSWORD"])
sys.stdout.write(text)
PY
else
  echo "==> Skipping DB bootstrap (SKIP_DB_BOOTSTRAP=1)"
fi

echo "==> Applying unmanaged Postgres secrets to $AAP_NS (PGHOST=$PGHOST)..."
export PGHOST
chmod +x "$SCRIPT_DIR/generate-postgres-secrets.sh"
"$SCRIPT_DIR/generate-postgres-secrets.sh" "$AAP_DB_PASSWORD" | oc_g apply -f -

echo "==> Applying AnsibleAutomationPlatform (Hub SC -> $HUB_STORAGE_CLASS)..."
oc_g apply -f "$AAP_OPENSHIFT/ansibleautomationplatform.yaml"
oc_g patch ansibleautomationplatform aap -n "$AAP_NS" --type=merge \
  -p "$(printf '{"spec":{"hub":{"file_storage_storage_class":"%s"}}}' "$HUB_STORAGE_CLASS")"

echo ""
echo "==> Done. Watch reconcile:"
echo "    oc --context $CTX get ansibleautomationplatform,pods -n $AAP_NS -w"
echo "Routes:"
echo "    oc --context $CTX get routes -n $AAP_NS"
