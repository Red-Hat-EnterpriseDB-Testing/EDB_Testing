#!/bin/bash
#
# RTO/RPO Measurement Script
# Measures Recovery Time Objective and Recovery Point Objective during DR tests
#
# Usage:
#   ./measure-rto-rpo.sh start <test-id>
#   ./measure-rto-rpo.sh milestone <test-id> <milestone-name>
#   ./measure-rto-rpo.sh complete <test-id>
#   ./measure-rto-rpo.sh report <test-id>
#

set -euo pipefail

# Configuration
METRICS_DIR="/tmp/dr-metrics"
NAMESPACE="ansible-automation-platform"
DB_NAMESPACE="edb-postgres"

# Parse arguments
ACTION="${1:-}"
TEST_ID="${2:-}"
MILESTONE_NAME="${3:-}"

if [ -z "$ACTION" ] || [ -z "$TEST_ID" ]; then
    echo "Usage: $0 <start|milestone|complete|report> <test-id> [milestone-name]"
    exit 1
fi

# Create metrics directory
mkdir -p "$METRICS_DIR"

# Metrics file for this test
METRICS_FILE="$METRICS_DIR/rto-rpo-$TEST_ID.json"

# Function: Get current timestamp in milliseconds
get_timestamp_ms() {
    # macOS (BSD) date doesn't support %N for nanoseconds
    # Use Python for cross-platform compatibility
    if command -v python3 &> /dev/null; then
        python3 -c 'import time; print(int(time.time() * 1000))'
    else
        # Fallback: seconds * 1000
        echo $(($(date +%s) * 1000))
    fi
}

# Function: Get current timestamp (human readable)
get_timestamp_human() {
    # macOS compatible format
    if command -v python3 &> /dev/null; then
        python3 -c 'from datetime import datetime; print(datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3])'
    else
        # Fallback: just date without milliseconds
        date +"%Y-%m-%d %H:%M:%S"
    fi
}

# Function: Calculate duration in seconds
calculate_duration() {
    local start_ms="$1"
    local end_ms="$2"

    local duration_ms=$((end_ms - start_ms))
    local duration_sec=$(awk "BEGIN {printf \"%.3f\", $duration_ms / 1000}")

    echo "$duration_sec"
}

# Function: Initialize metrics file
init_metrics() {
    cat > "$METRICS_FILE" <<EOF
{
  "test_id": "$TEST_ID",
  "start_time": "$(get_timestamp_human)",
  "start_time_ms": $(get_timestamp_ms),
  "milestones": {},
  "rto_seconds": null,
  "rpo_seconds": null,
  "status": "in_progress"
}
EOF
}

# Function: Add milestone
add_milestone() {
    local milestone="$1"
    local timestamp_ms=$(get_timestamp_ms)
    local timestamp_human=$(get_timestamp_human)

    # Read current metrics
    local start_time_ms=$(grep '"start_time_ms"' "$METRICS_FILE" | grep -o '[0-9]*')

    # Calculate elapsed time
    local elapsed=$(calculate_duration "$start_time_ms" "$timestamp_ms")

    # Update metrics file (using temp file for atomic update)
    local temp_file
    temp_file=$(mktemp "${METRICS_FILE}.XXXXXX")

    # Use jq if available for safe JSON manipulation
    if command -v jq &> /dev/null; then
        jq ".milestones.\"$milestone\" = {\"timestamp\": \"$timestamp_human\", \"timestamp_ms\": $timestamp_ms, \"elapsed_seconds\": $elapsed}" \
            "$METRICS_FILE" > "$temp_file"
        # Atomic replacement (POSIX compliant)
        mv "$temp_file" "$METRICS_FILE"
    else
        # Fallback: use Python for JSON manipulation (more reliable than sed)
        if command -v python3 &> /dev/null; then
            python3 <<PY > "$temp_file"
import json
import sys

with open("$METRICS_FILE", "r") as f:
    data = json.load(f)

data["milestones"]["$milestone"] = {
    "timestamp": "$timestamp_human",
    "timestamp_ms": $timestamp_ms,
    "elapsed_seconds": $elapsed
}

json.dump(data, sys.stdout, indent=2)
PY
            mv "$temp_file" "$METRICS_FILE"
        else
            echo "ERROR: Neither jq nor python3 available for JSON manipulation" >&2
            rm -f "$temp_file"
            return 1
        fi
    fi

    echo "✓ Milestone recorded: $milestone (elapsed: ${elapsed}s)"
}

# Function: Check database is primary
check_database_primary() {
    local cluster_context="$1"

    oc config use-context "$cluster_context" &> /dev/null

    local db_pod=$(oc get pods -n "$DB_NAMESPACE" -l "cnpg.io/cluster=postgresql,role=primary" -o name 2>/dev/null | head -1)

    if [ -z "$db_pod" ]; then
        return 1
    fi

    local in_recovery=$(oc exec -n "$DB_NAMESPACE" "$db_pod" -- psql -U postgres -t -c "SELECT pg_is_in_recovery();" 2>/dev/null | tr -d '[:space:]')

    if [ "$in_recovery" == "f" ]; then
        return 0
    else
        return 1
    fi
}

# Function: Check AAP availability
check_aap_available() {
    local aap_url="$1"

    if curl -k -s --max-time 5 "$aap_url/api/v2/ping/" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function: Measure RPO
measure_rpo() {
    local cluster_context="$1"

    oc config use-context "$cluster_context" &> /dev/null

    # Get last transaction timestamp from database
    local db_pod=$(oc get pods -n "$DB_NAMESPACE" -l "cnpg.io/cluster=postgresql,role=primary" -o name 2>/dev/null | head -1)

    if [ -z "$db_pod" ]; then
        echo "0"
        return
    fi

    # Query pg_stat_replication for last WAL receive time (this is approximate)
    # In reality, RPO should be measured by comparing last known good transaction before failure
    # For now, we'll use replication lag at time of promotion

    local rpo_query="SELECT COALESCE(EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp())), 0);"
    local rpo_seconds=$(oc exec -n "$DB_NAMESPACE" "$db_pod" -- psql -U postgres -t -c "$rpo_query" 2>/dev/null | tr -d '[:space:]' || echo "0")

    echo "$rpo_seconds"
}

# Main action handler
case "$ACTION" in
    start)
        echo "============================================="
        echo "Starting RTO/RPO Measurement"
        echo "============================================="
        echo "Test ID: $TEST_ID"
        echo "Start Time: $(get_timestamp_human)"
        echo "============================================="
        echo ""

        init_metrics

        echo "✓ Metrics file initialized: $METRICS_FILE"
        echo ""
        echo "Record milestones with:"
        echo "  $0 milestone $TEST_ID <milestone-name>"
        echo ""
        echo "Complete test with:"
        echo "  $0 complete $TEST_ID"
        ;;

    milestone)
        if [ -z "$MILESTONE_NAME" ]; then
            echo "❌ Milestone name required"
            echo "Usage: $0 milestone $TEST_ID <milestone-name>"
            exit 1
        fi

        if [ ! -f "$METRICS_FILE" ]; then
            echo "❌ Metrics file not found: $METRICS_FILE"
            echo "Start the test first with: $0 start $TEST_ID"
            exit 1
        fi

        add_milestone "$MILESTONE_NAME"
        ;;

    complete)
        if [ ! -f "$METRICS_FILE" ]; then
            echo "❌ Metrics file not found: $METRICS_FILE"
            exit 1
        fi

        echo "============================================="
        echo "Completing RTO/RPO Measurement"
        echo "============================================="
        echo "Test ID: $TEST_ID"
        echo ""

        # Add final milestone
        add_milestone "test_complete"

        # Calculate final RTO
        start_time_ms=$(grep '"start_time_ms"' "$METRICS_FILE" | grep -o '[0-9]*')
        end_time_ms=$(get_timestamp_ms)
        rto=$(calculate_duration "$start_time_ms" "$end_time_ms")

        # Update metrics file with final RTO (atomic update)
        local temp_file
        temp_file=$(mktemp "${METRICS_FILE}.XXXXXX")
        local end_time_human
        end_time_human=$(get_timestamp_human)

        if command -v jq &> /dev/null; then
            jq ".rto_seconds = $rto | .status = \"completed\" | .end_time = \"$end_time_human\"" \
                "$METRICS_FILE" > "$temp_file"
            mv "$temp_file" "$METRICS_FILE"
        elif command -v python3 &> /dev/null; then
            python3 <<PY > "$temp_file"
import json

with open("$METRICS_FILE", "r") as f:
    data = json.load(f)

data["rto_seconds"] = $rto
data["status"] = "completed"
data["end_time"] = "$end_time_human"

json.dump(data, sys.stdout, indent=2)
PY
            mv "$temp_file" "$METRICS_FILE"
        else
            echo "ERROR: Neither jq nor python3 available for JSON manipulation" >&2
            rm -f "$temp_file"
            exit 1
        fi

        echo "✓ Test completed"
        echo "✓ Total RTO: ${rto} seconds"
        echo ""
        echo "Generate report with: $0 report $TEST_ID"
        ;;

    report)
        if [ ! -f "$METRICS_FILE" ]; then
            echo "❌ Metrics file not found: $METRICS_FILE"
            exit 1
        fi

        echo "============================================="
        echo "RTO/RPO Measurement Report"
        echo "============================================="
        echo "Test ID: $TEST_ID"
        echo ""

        # Parse and display metrics
        echo "Test Timeline:"
        echo "-------------------------------------------"

        start_time=$(grep '"start_time"' "$METRICS_FILE" | cut -d'"' -f4)
        echo "Start: $start_time"

        # Extract milestones
        grep -A 4 '"milestones"' "$METRICS_FILE" | grep '"elapsed_seconds"' | while read -r line; do
            milestone=$(echo "$line" | grep -B 2 'elapsed_seconds' "$METRICS_FILE" | head -1 | cut -d'"' -f2 || echo "unknown")
            elapsed=$(echo "$line" | grep -o '[0-9.]*')
            timestamp=$(echo "$line" | grep -B 1 'elapsed_seconds' "$METRICS_FILE" | grep 'timestamp"' | cut -d'"' -f4 || echo "unknown")

            printf "  + %-30s %10.3fs  (%s)\n" "$milestone" "$elapsed" "$timestamp"
        done

        echo "-------------------------------------------"
        echo ""

        # Display RTO
        rto=$(grep '"rto_seconds"' "$METRICS_FILE" | grep -o '[0-9.]*' || echo "unknown")
        echo "Recovery Time Objective (RTO):"
        echo "  Measured: ${rto}s"

        # Compare to target
        TARGET_RTO=300  # 5 minutes = 300 seconds
        if [ "$rto" != "unknown" ]; then
            if (( $(awk "BEGIN {print ($rto <= $TARGET_RTO)}") )); then
                echo "  Status: ✅ PASSED (target: ${TARGET_RTO}s)"
            else
                echo "  Status: ❌ FAILED (target: ${TARGET_RTO}s, exceeded by $(awk "BEGIN {print $rto - $TARGET_RTO}")s)"
            fi
        fi

        echo ""

        # Display RPO (if measured)
        rpo=$(grep '"rpo_seconds"' "$METRICS_FILE" | grep -o '[0-9.]*' || echo "unknown")

        if [ "$rpo" != "unknown" ] && [ "$rpo" != "null" ]; then
            echo "Recovery Point Objective (RPO):"
            echo "  Measured: ${rpo}s"

            TARGET_RPO=5  # 5 seconds
            if (( $(awk "BEGIN {print ($rpo <= $TARGET_RPO)}") )); then
                echo "  Status: ✅ PASSED (target: ${TARGET_RPO}s)"
            else
                echo "  Status: ⚠️  WARNING (target: ${TARGET_RPO}s, exceeded by $(awk "BEGIN {print $rpo - $TARGET_RPO}")s)"
            fi
        else
            echo "Recovery Point Objective (RPO):"
            echo "  Status: ℹ️  Not measured (manual validation required)"
        fi

        echo ""
        echo "============================================="
        echo "Full metrics: $METRICS_FILE"
        echo "============================================="
        ;;

    *)
        echo "❌ Invalid action: $ACTION"
        echo "Usage: $0 <start|milestone|complete|report> <test-id> [milestone-name]"
        exit 1
        ;;
esac
