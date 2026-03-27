#!/usr/bin/env bash
# Emit four AAP unmanaged Postgres secrets for the AnsibleAutomationPlatform CR in this directory.
# Usage: ./generate-postgres-secrets.sh '<password>'
#   Password must not contain ', ", or \ per Red Hat AAP external DB guidance.
#
# Env overrides:
#   PGHOST (default postgresql-rw.edb-postgres.svc.cluster.local)
#   PGPORT (default 5432)
#   PGUSER (default aap)
#   SSLMODE (default prefer)
#   AAP_NAMESPACE (default ansible-automation-platform)
set -euo pipefail

PASS="${1:?usage: $0 <database-password>}"
PGHOST="${PGHOST:-postgresql-rw.edb-postgres.svc.cluster.local}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-aap}"
SSLMODE="${SSLMODE:-prefer}"
NS="${AAP_NAMESPACE:-ansible-automation-platform}"

emit() {
  local name=$1 db=$2
  cat <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: $name
  namespace: $NS
type: Opaque
stringData:
  host: $PGHOST
  port: "$PGPORT"
  database: $db
  username: $PGUSER
  password: $PASS
  sslmode: $SSLMODE
  target_session_attrs: read-write
  type: unmanaged
---
EOF
}

emit external-postgres-configuration-gateway platform_gateway
emit external-postgres-configuration-controller automation_controller
emit external-postgres-configuration-hub automation_hub
emit external-postgres-configuration-eda automation_eda
