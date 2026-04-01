#!/bin/bash
# DR Failover Test Orchestration Script
# Automated disaster recovery testing with RTO/RPO measurement
#
# Usage:
#   ./dr-failover-test.sh [options]
#
# Options:
#   --test-id <id>           Test identifier (default: auto-generated)
#   --dc1-context <context>  DC1 cluster context
#   --dc2-context <context>  DC2 cluster context
#   --skip-failback          Skip automatic failback after test
#   --dry-run                Simulate test without actual failover
#

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="ansible-automation-platform"
DB_NAMESPACE="edb-postgres"
TEST_RESULTS_DIR="/tmp/dr-test-results"
KUBECONFIG_FILE="${KUBECONFIG:-$HOME/.kube/config}"

# Default values
TEST_ID="dr-test-$(date +%Y%m%d-%H%M%S)"
DC1_CONTEXT=""
DC2_CONTEXT=""
SKIP_FAILBACK=false
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --test-id)
            TEST_ID="$2"
            shift 2
            ;;
        --dc1-context)
            DC1_CONTEXT="$2"
            shift 2
            ;;
        --dc2-context)
            DC2_CONTEXT="$2"
            shift 2
            ;;
        --skip-failback)
            SKIP_FAILBACK=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--test-id <id>] [--dc1-context <ctx>] [--dc2-context <ctx>] [--skip-failback] [--dry-run]"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$DC1_CONTEXT" ] || [ -z "$DC2_CONTEXT" ]; then
    echo "❌ DC1 and DC2 cluster contexts are required"
    echo "Usage: $0 --dc1-context <dc1> --dc2-context <dc2>"
    exit 1
fi

# Create results directory
mkdir -p "$TEST_RESULTS_DIR"

# Test log file
TEST_LOG="$TEST_RESULTS_DIR/${TEST_ID}.log"

# Logging function
log() {
    local message="$1"
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] $message" | tee -a "$TEST_LOG"
}

log_section() {
    local title="$1"
    echo "" | tee -a "$TEST_LOG"
    echo "=============================================" | tee -a "$TEST_LOG"
    echo "$title" | tee -a "$TEST_LOG"
    echo "=============================================" | tee -a "$TEST_LOG"
}

# Set kubeconfig
export KUBECONFIG="$KUBECONFIG_FILE"

# Start test
log_section "DR Failover Test - $TEST_ID"

log "Test ID: $TEST_ID"
log "DC1 Context: $DC1_CONTEXT"
log "DC2 Context: $DC2_CONTEXT"
log "Skip Failback: $SKIP_FAILBACK"
log "Dry Run: $DRY_RUN"
log ""

if [ "$DRY_RUN" == "true" ]; then
    log "⚠️  DRY RUN MODE - No actual failover will be performed"
    log ""
fi

# Initialize RTO/RPO measurement
log "Initializing RTO/RPO measurement..."
"$SCRIPT_DIR/measure-rto-rpo.sh" start "$TEST_ID" >> "$TEST_LOG" 2>&1
log "✓ RTO/RPO tracking started"
log ""

# Phase 1: Pre-flight Checks
log_section "Phase 1: Pre-flight Checks"

# Check DC1 cluster connectivity
log "Checking DC1 cluster connectivity..."
if oc config use-context "$DC1_CONTEXT" >> "$TEST_LOG" 2>&1; then
    log "✓ DC1 cluster accessible"
else
    log "❌ Cannot access DC1 cluster"
    exit 1
fi

# Check DC2 cluster connectivity
log "Checking DC2 cluster connectivity..."
if oc config use-context "$DC2_CONTEXT" >> "$TEST_LOG" 2>&1; then
    log "✓ DC2 cluster accessible"
else
    log "❌ Cannot access DC2 cluster"
    exit 1
fi

# Check DC1 database status
log "Checking DC1 database status..."
oc config use-context "$DC1_CONTEXT" >> "$TEST_LOG" 2>&1

DC1_DB_POD=$(oc get pods -n "$DB_NAMESPACE" -l "cnpg.io/cluster=postgresql,role=primary" -o name 2>/dev/null | head -1 || echo "")

if [ -z "$DC1_DB_POD" ]; then
    log "❌ No primary database found in DC1"
    exit 1
fi

DC1_DB_RECOVERY=$(oc exec -n "$DB_NAMESPACE" "$DC1_DB_POD" -- psql -U postgres -t -c "SELECT pg_is_in_recovery();" 2>/dev/null | tr -d '[:space:]' || echo "unknown")

if [ "$DC1_DB_RECOVERY" == "f" ]; then
    log "✓ DC1 database is PRIMARY"
else
    log "❌ DC1 database is not in primary mode"
    exit 1
fi

# Check DC1 AAP status
log "Checking DC1 AAP status..."
DC1_AAP_PODS=$(oc get pods -n "$NAMESPACE" --field-selector=status.phase=Running 2>/dev/null | grep -E "automation|aap-gateway" | wc -l || echo "0")

if [ "$DC1_AAP_PODS" -gt 0 ]; then
    log "✓ DC1 AAP running ($DC1_AAP_PODS pods)"
else
    log "⚠️  DC1 AAP has no running pods"
fi

# Check DC2 database status (should be replica)
log "Checking DC2 database status..."
oc config use-context "$DC2_CONTEXT" >> "$TEST_LOG" 2>&1

DC2_DB_POD=$(oc get pods -n "$DB_NAMESPACE" -l "cnpg.io/cluster=postgresql-replica" -o name 2>/dev/null | head -1 || echo "")

if [ -z "$DC2_DB_POD" ]; then
    log "⚠️  No replica database found in DC2"
else
    DC2_DB_RECOVERY=$(oc exec -n "$DB_NAMESPACE" "$DC2_DB_POD" -- psql -U postgres -t -c "SELECT pg_is_in_recovery();" 2>/dev/null | tr -d '[:space:]' || echo "unknown")

    if [ "$DC2_DB_RECOVERY" == "t" ]; then
        log "✓ DC2 database is REPLICA (as expected)"
    else
        log "⚠️  DC2 database is not in replica mode"
    fi
fi

# Check DC2 AAP status (should be scaled down)
log "Checking DC2 AAP status..."
DC2_AAP_PODS=$(oc get pods -n "$NAMESPACE" --field-selector=status.phase=Running 2>/dev/null | grep -E "automation|aap-gateway" | wc -l || echo "0")

if [ "$DC2_AAP_PODS" -eq 0 ]; then
    log "✓ DC2 AAP scaled down (as expected)"
else
    log "⚠️  DC2 AAP has $DC2_AAP_PODS running pods (expected 0)"
fi

# Check replication lag
log "Checking replication lag..."
oc config use-context "$DC1_CONTEXT" >> "$TEST_LOG" 2>&1

REP_LAG=$(oc exec -n "$DB_NAMESPACE" "$DC1_DB_POD" -- psql -U postgres -t -c "SELECT COALESCE(EXTRACT(EPOCH FROM (now() - replay_lsn_age)), 0) FROM pg_stat_replication LIMIT 1;" 2>/dev/null | tr -d '[:space:]' || echo "0")

log "  Replication lag: ${REP_LAG}s"

if (( $(awk "BEGIN {print ($REP_LAG <= 30)}") )); then
    log "✓ Replication lag acceptable (<30s)"
else
    log "⚠️  Replication lag high (${REP_LAG}s)"
fi

"$SCRIPT_DIR/measure-rto-rpo.sh" milestone "$TEST_ID" "preflight_complete" >> "$TEST_LOG" 2>&1

log ""
log "✅ Pre-flight checks complete"
log ""

# Phase 2: Create Baseline
log_section "Phase 2: Create Data Baseline"

log "Creating AAP data baseline from DC1..."
oc config use-context "$DC1_CONTEXT" >> "$TEST_LOG" 2>&1

if "$SCRIPT_DIR/validate-aap-data.sh" create-baseline "$DC1_CONTEXT" >> "$TEST_LOG" 2>&1; then
    log "✓ Baseline created successfully"
else
    log "⚠️  Baseline creation had warnings (check log)"
fi

"$SCRIPT_DIR/measure-rto-rpo.sh" milestone "$TEST_ID" "baseline_created" >> "$TEST_LOG" 2>&1

log ""

# Phase 3: Simulate Failure
log_section "Phase 3: Simulate DC1 Failure"

if [ "$DRY_RUN" == "true" ]; then
    log "⚠️  DRY RUN: Skipping actual failover simulation"
    log "In production, this would:"
    log "  1. Scale DC1 database to 0 replicas"
    log "  2. Wait for EFM to detect failure"
    log "  3. Monitor automatic promotion in DC2"
else
    log "Simulating DC1 database failure..."
    log "  → Scaling DC1 PostgreSQL cluster to 0 replicas"

    oc config use-context "$DC1_CONTEXT" >> "$TEST_LOG" 2>&1

    # Scale down database (simulates DC failure)
    if oc scale cluster postgresql -n "$DB_NAMESPACE" --replicas=0 >> "$TEST_LOG" 2>&1; then
        log "✓ DC1 database scaled to 0"
    else
        log "❌ Failed to scale down DC1 database"
        exit 1
    fi

    "$SCRIPT_DIR/measure-rto-rpo.sh" milestone "$TEST_ID" "dc1_failure_simulated" >> "$TEST_LOG" 2>&1

    log ""
    log "Waiting for EFM to detect failure and trigger promotion..."
    log "(This may take 30-60 seconds based on EFM health check interval)"
    log ""

    # Poll DC2 for database promotion
    PROMOTION_TIMEOUT=300  # 5 minutes
    ELAPSED=0
    PROMOTED=false

    oc config use-context "$DC2_CONTEXT" >> "$TEST_LOG" 2>&1

    while [ $ELAPSED -lt $PROMOTION_TIMEOUT ]; do
        # Check if DC2 database is now primary
        DC2_DB_POD=$(oc get pods -n "$DB_NAMESPACE" -l "cnpg.io/cluster=postgresql-replica" -o name 2>/dev/null | head -1 || echo "")

        if [ -n "$DC2_DB_POD" ]; then
            # Add retry logic for database query (handles transient failures during promotion)
            local attempt=0
            local max_attempts=3
            local query_success=false

            while [ $attempt -lt $max_attempts ]; do
                if DC2_RECOVERY=$(oc exec -n "$DB_NAMESPACE" "$DC2_DB_POD" -- \
                    psql -U postgres -t -c "SELECT pg_is_in_recovery();" 2>&1); then
                    DC2_RECOVERY=$(echo "$DC2_RECOVERY" | tr -d '[:space:]')
                    query_success=true
                    break
                else
                    log "  Database query failed (attempt $((attempt+1))/$max_attempts): ${DC2_RECOVERY}"
                    ((attempt++)) || true
                    if [ $attempt -lt $max_attempts ]; then
                        sleep 2
                    fi
                fi
            done

            if [ "$query_success" == "true" ]; then
                if [ "$DC2_RECOVERY" == "f" ]; then
                    log "✅ DC2 database promoted to PRIMARY"
                    PROMOTED=true
                    "$SCRIPT_DIR/measure-rto-rpo.sh" milestone "$TEST_ID" "database_promoted" >> "$TEST_LOG" 2>&1
                    break
                elif [ "$DC2_RECOVERY" == "t" ]; then
                    log "  Database still in recovery mode (${ELAPSED}s elapsed)"
                else
                    log "  Unexpected recovery state: $DC2_RECOVERY"
                fi
            else
                log "  Database query failed after $max_attempts attempts, will retry in 5s"
            fi
        else
            log "  No database pod found in DC2 (${ELAPSED}s elapsed)"
        fi

        sleep 5
        ELAPSED=$((ELAPSED + 5))
    done

    if [ "$PROMOTED" == "false" ]; then
        log "❌ Database promotion timeout (${PROMOTION_TIMEOUT}s)"
        log "Manual intervention required"
        exit 1
    fi

    log ""
    log "Waiting for AAP to scale up in DC2..."
    log "(EFM post-promotion hook should trigger scale-aap-up.sh)"
    log ""

    # Poll for AAP pods in DC2
    AAP_TIMEOUT=180  # 3 minutes
    ELAPSED=0
    AAP_READY=false

    while [ $ELAPSED -lt $AAP_TIMEOUT ]; do
        READY_PODS=$(oc get pods -n "$NAMESPACE" --field-selector=status.phase=Running 2>/dev/null | grep -E "automation|aap-gateway" | grep "1/1\|2/2" | wc -l || echo "0")

        if [ "$READY_PODS" -ge 5 ]; then
            log "✅ AAP pods ready in DC2 ($READY_PODS pods)"
            AAP_READY=true
            "$SCRIPT_DIR/measure-rto-rpo.sh" milestone "$TEST_ID" "aap_ready" >> "$TEST_LOG" 2>&1
            break
        fi

        sleep 10
        ELAPSED=$((ELAPSED + 10))
        log "  AAP pods starting... $READY_PODS ready (${ELAPSED}s elapsed)"
    done

    if [ "$AAP_READY" == "false" ]; then
        log "⚠️  AAP pods not fully ready after ${AAP_TIMEOUT}s"
        log "Continuing with validation..."
    fi
fi

log ""

# Phase 4: Validate Failover
log_section "Phase 4: Validate Failover"

if [ "$DRY_RUN" == "true" ]; then
    log "⚠️  DRY RUN: Skipping validation"
else
    log "Validating DC2 database status..."
    oc config use-context "$DC2_CONTEXT" >> "$TEST_LOG" 2>&1

    DC2_DB_POD=$(oc get pods -n "$DB_NAMESPACE" -l "cnpg.io/cluster=postgresql-replica" -o name 2>/dev/null | head -1 || echo "")

    if [ -n "$DC2_DB_POD" ]; then
        DC2_RECOVERY=$(oc exec -n "$DB_NAMESPACE" "$DC2_DB_POD" -- psql -U postgres -t -c "SELECT pg_is_in_recovery();" 2>/dev/null | tr -d '[:space:]')

        if [ "$DC2_RECOVERY" == "f" ]; then
            log "✓ DC2 database confirmed as PRIMARY"
        else
            log "❌ DC2 database still in replica mode"
            exit 1
        fi
    fi

    log ""
    log "Validating AAP data integrity..."

    if "$SCRIPT_DIR/validate-aap-data.sh" validate "$DC2_CONTEXT" >> "$TEST_LOG" 2>&1; then
        log "✓ Data validation PASSED"
    else
        log "⚠️  Data validation had discrepancies (check log)"
    fi

    "$SCRIPT_DIR/measure-rto-rpo.sh" milestone "$TEST_ID" "validation_complete" >> "$TEST_LOG" 2>&1

    log ""
    log "Testing AAP functionality..."

    # Get AAP URL
    AAP_ROUTE=$(oc get route -n "$NAMESPACE" -o jsonpath='{.items[0].spec.host}' 2>/dev/null || echo "")

    if [ -n "$AAP_ROUTE" ]; then
        AAP_URL="https://$AAP_ROUTE"
        log "  AAP URL: $AAP_URL"

        if curl -k -s --max-time 10 "$AAP_URL/api/v2/ping/" > /dev/null 2>&1; then
            log "✓ AAP API responding"
            "$SCRIPT_DIR/measure-rto-rpo.sh" milestone "$TEST_ID" "aap_api_verified" >> "$TEST_LOG" 2>&1
        else
            log "⚠️  AAP API not responding"
        fi
    else
        log "⚠️  Could not determine AAP URL"
    fi
fi

log ""

# Complete RTO/RPO measurement
log_section "Phase 5: Measure RTO/RPO"

"$SCRIPT_DIR/measure-rto-rpo.sh" complete "$TEST_ID" >> "$TEST_LOG" 2>&1

log ""
log "Generating RTO/RPO report..."
"$SCRIPT_DIR/measure-rto-rpo.sh" report "$TEST_ID" | tee -a "$TEST_LOG"

log ""

# Phase 6: Failback (Optional)
if [ "$SKIP_FAILBACK" == "false" ] && [ "$DRY_RUN" == "false" ]; then
    log_section "Phase 6: Failback to DC1"

    log "⚠️  Automatic failback not yet implemented"
    log "To restore DC1 as primary:"
    log "  1. Restore DC1 database cluster:"
    log "     oc scale cluster postgresql -n $DB_NAMESPACE --replicas=2 --context $DC1_CONTEXT"
    log "  2. Wait for DC1 to sync as replica"
    log "  3. Manually promote DC1 and demote DC2"
    log "  4. Scale down DC2 AAP and scale up DC1 AAP"
    log ""
else
    log_section "Failback Skipped"
    log "DC2 remains active as primary datacenter"
    log ""
fi

# Generate final report
log_section "Test Complete - Summary"

log "Test ID: $TEST_ID"
log "Status: ✅ COMPLETED"
log ""
log "Results:"
log "  - Full log: $TEST_LOG"
log "  - RTO/RPO metrics: /tmp/dr-metrics/rto-rpo-$TEST_ID.json"
log "  - Validation report: /tmp/aap-validation-results/validation-report-*.txt"
log ""

if [ "$DRY_RUN" == "false" ]; then
    log "⚠️  DC2 is now the active datacenter"
    log "Next steps:"
    log "  1. Review test results and metrics"
    log "  2. Update runbooks based on findings"
    log "  3. Plan failback to DC1 (if desired)"
else
    log "ℹ️  Dry run completed - no changes made"
fi

log ""
log "============================================="

exit 0
