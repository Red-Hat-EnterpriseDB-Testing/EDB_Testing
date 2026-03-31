#!/bin/bash
#
# Copyright 2026 EnterpriseDB Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# AAP Data Validation Script
# Validates AAP data integrity after failover or DR events
#
# Usage:
#   ./validate-aap-data.sh create-baseline <cluster-context>
#   ./validate-aap-data.sh validate <cluster-context>
#

set -e

# Configuration
NAMESPACE="ansible-automation-platform"
BASELINE_DIR="/tmp/aap-baseline"
RESULTS_DIR="/tmp/aap-validation-results"
KUBECONFIG_FILE="${KUBECONFIG:-$HOME/.kube/config}"

# Parse arguments
ACTION="${1:-validate}"
CLUSTER_CONTEXT="${2:-}"

if [ -z "$CLUSTER_CONTEXT" ]; then
    echo "Usage: $0 <create-baseline|validate> <cluster-context>"
    exit 1
fi

# Create directories
mkdir -p "$BASELINE_DIR" "$RESULTS_DIR"

# Set timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "============================================="
echo "AAP Data Validation"
echo "============================================="
echo "Action: $ACTION"
echo "Cluster: $CLUSTER_CONTEXT"
echo "Timestamp: $TIMESTAMP"
echo "============================================="
echo ""

# Set kubeconfig
export KUBECONFIG="$KUBECONFIG_FILE"

# Switch to target context
echo "Switching to context: $CLUSTER_CONTEXT"
oc config use-context "$CLUSTER_CONTEXT" || {
    echo "❌ Failed to switch context"
    exit 1
}

# Get AAP route/URL
echo "Detecting AAP URL..."
AAP_ROUTE=$(oc get route -n "$NAMESPACE" -o jsonpath='{.items[?(@.spec.to.name=="aap-gateway-service")].spec.host}' 2>/dev/null || echo "")

if [ -z "$AAP_ROUTE" ]; then
    # Fallback: get any route in the namespace
    AAP_ROUTE=$(oc get route -n "$NAMESPACE" -o jsonpath='{.items[0].spec.host}' 2>/dev/null || echo "")
fi

if [ -z "$AAP_ROUTE" ]; then
    echo "❌ Could not detect AAP route"
    exit 1
fi

AAP_URL="https://$AAP_ROUTE"
echo "AAP URL: $AAP_URL"
echo ""

# Get AAP admin credentials from secret
echo "Retrieving AAP credentials..."
AAP_ADMIN_USER=$(oc get secret aap-admin-password -n "$NAMESPACE" -o jsonpath='{.data.username}' 2>/dev/null | base64 -d || echo "admin")
AAP_ADMIN_PASSWORD=$(oc get secret aap-admin-password -n "$NAMESPACE" -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "")

if [ -z "$AAP_ADMIN_PASSWORD" ]; then
    echo "⚠️  Could not retrieve admin password from secret"
    echo "Checking for tower-admin-password secret..."
    AAP_ADMIN_PASSWORD=$(oc get secret tower-admin-password -n "$NAMESPACE" -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "")
fi

if [ -z "$AAP_ADMIN_PASSWORD" ]; then
    echo "❌ Could not retrieve AAP admin password"
    echo "Please set AAP_ADMIN_PASSWORD environment variable"
    exit 1
fi

echo "✓ Credentials retrieved"
echo ""

# Function: Get AAP API token
get_aap_token() {
    local token_response

    token_response=$(curl -k -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"$AAP_ADMIN_USER\",\"password\":\"$AAP_ADMIN_PASSWORD\"}" \
        "$AAP_URL/api/v2/tokens/" 2>/dev/null || echo "")

    if [ -z "$token_response" ]; then
        return 1
    fi

    echo "$token_response" | grep -o '"token":"[^"]*' | cut -d'"' -f4
}

# Function: Call AAP API
call_aap_api() {
    local endpoint="$1"
    local auth_token=$2

    curl -k -s -H "Authorization: Bearer $auth_token" \
        "$AAP_URL/api/v2/$endpoint" 2>/dev/null || echo "{}"
}

# Function: Extract count from API response
extract_count() {
    local response="$1"
    echo "$response" | grep -o '"count":[0-9]*' | head -1 | cut -d':' -f2 || echo "0"
}

# Get API token
echo "Authenticating to AAP API..."
AAP_TOKEN=$(get_aap_token)

if [ -z "$AAP_TOKEN" ]; then
    echo "❌ Failed to obtain AAP API token"
    echo "Check credentials and AAP availability"
    exit 1
fi

echo "✓ Authenticated successfully"
echo ""

# Collect metrics
echo "Collecting AAP metrics..."

declare -A METRICS

# Organizations
response=$(call_aap_api "organizations/" "$AAP_TOKEN")
METRICS[organizations]=$(extract_count "$response")
echo "  Organizations: ${METRICS[organizations]}"

# Users
response=$(call_aap_api "users/" "$AAP_TOKEN")
METRICS[users]=$(extract_count "$response")
echo "  Users: ${METRICS[users]}"

# Teams
response=$(call_aap_api "teams/" "$AAP_TOKEN")
METRICS[teams]=$(extract_count "$response")
echo "  Teams: ${METRICS[teams]}"

# Inventories
response=$(call_aap_api "inventories/" "$AAP_TOKEN")
METRICS[inventories]=$(extract_count "$response")
echo "  Inventories: ${METRICS[inventories]}"

# Hosts
response=$(call_aap_api "hosts/" "$AAP_TOKEN")
METRICS[hosts]=$(extract_count "$response")
echo "  Hosts: ${METRICS[hosts]}"

# Projects
response=$(call_aap_api "projects/" "$AAP_TOKEN")
METRICS[projects]=$(extract_count "$response")
echo "  Projects: ${METRICS[projects]}"

# Job Templates
response=$(call_aap_api "job_templates/" "$AAP_TOKEN")
METRICS[job_templates]=$(extract_count "$response")
echo "  Job Templates: ${METRICS[job_templates]}"

# Workflow Job Templates
response=$(call_aap_api "workflow_job_templates/" "$AAP_TOKEN")
METRICS[workflow_templates]=$(extract_count "$response")
echo "  Workflow Templates: ${METRICS[workflow_templates]}"

# Credentials
response=$(call_aap_api "credentials/" "$AAP_TOKEN")
METRICS[credentials]=$(extract_count "$response")
echo "  Credentials: ${METRICS[credentials]}"

# Jobs (all time)
response=$(call_aap_api "jobs/" "$AAP_TOKEN")
METRICS[jobs_total]=$(extract_count "$response")
echo "  Total Jobs: ${METRICS[jobs_total]}"

# Jobs (successful)
response=$(call_aap_api "jobs/?status=successful" "$AAP_TOKEN")
METRICS[jobs_successful]=$(extract_count "$response")
echo "  Successful Jobs: ${METRICS[jobs_successful]}"

# Jobs (failed)
response=$(call_aap_api "jobs/?status=failed" "$AAP_TOKEN")
METRICS[jobs_failed]=$(extract_count "$response")
echo "  Failed Jobs: ${METRICS[jobs_failed]}"

# Schedules
response=$(call_aap_api "schedules/" "$AAP_TOKEN")
METRICS[schedules]=$(extract_count "$response")
echo "  Schedules: ${METRICS[schedules]}"

echo ""

# Perform action based on mode
if [ "$ACTION" == "create-baseline" ]; then
    echo "Creating baseline snapshot..."

    BASELINE_FILE="$BASELINE_DIR/aap-baseline-$TIMESTAMP.json"

    # Create JSON baseline
    cat > "$BASELINE_FILE" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "cluster": "$CLUSTER_CONTEXT",
  "aap_url": "$AAP_URL",
  "metrics": {
$(for key in "${!METRICS[@]}"; do
    echo "    \"$key\": ${METRICS[$key]},"
done | sed '$ s/,$//')
  }
}
EOF

    # Create symlink to latest baseline
    ln -sf "$BASELINE_FILE" "$BASELINE_DIR/aap-baseline-latest.json"

    echo "✅ Baseline created: $BASELINE_FILE"
    echo ""
    echo "Baseline metrics saved. Use this baseline for future validation."

    exit 0

elif [ "$ACTION" == "validate" ]; then
    echo "Validating against baseline..."

    # Find latest baseline
    BASELINE_FILE="$BASELINE_DIR/aap-baseline-latest.json"

    if [ ! -f "$BASELINE_FILE" ]; then
        echo "❌ No baseline found at $BASELINE_FILE"
        echo "Create a baseline first with: $0 create-baseline <cluster-context>"
        exit 1
    fi

    echo "Using baseline: $BASELINE_FILE"
    echo ""

    # Load baseline metrics
    declare -A BASELINE_METRICS

    while IFS=: read -r key value; do
        key=$(echo "$key" | tr -d ' "')
        value=$(echo "$value" | tr -d ' ,' | grep -o '[0-9]*')
        if [ -n "$key" ] && [ -n "$value" ]; then
            BASELINE_METRICS[$key]=$value
        fi
    done < <(grep -A 20 '"metrics"' "$BASELINE_FILE" | grep -v 'metrics\|{' | grep ':')

    # Compare metrics
    echo "Comparing current state to baseline:"
    echo "-------------------------------------------"

    DISCREPANCIES=0
    WARNINGS=0

    declare -A COMPARISON_RESULTS

    for key in "${!BASELINE_METRICS[@]}"; do
        baseline_value=${BASELINE_METRICS[$key]}
        current_value=${METRICS[$key]:-0}

        # Calculate difference
        diff=$((current_value - baseline_value))
        diff_pct=0

        if [ "$baseline_value" -gt 0 ]; then
            diff_pct=$(awk "BEGIN {printf \"%.1f\", ($diff / $baseline_value) * 100}")
        fi

        # Determine status
        status="✓"
        if [ "$diff" -eq 0 ]; then
            status="✓"
        elif [ "$diff" -gt 0 ]; then
            status="↗"
            # Jobs increasing is expected, others are warnings
            if [[ "$key" =~ ^jobs_ ]]; then
                WARNINGS=$((WARNINGS + 1))
            else
                WARNINGS=$((WARNINGS + 1))
            fi
        else
            status="↘"
            # Data loss is a critical discrepancy
            if [[ ! "$key" =~ ^jobs_ ]]; then
                DISCREPANCIES=$((DISCREPANCIES + 1))
            fi
        fi

        printf "  %-25s %s  Baseline: %-6s Current: %-6s Diff: %+d (%s%%)\n" \
            "$key" "$status" "$baseline_value" "$current_value" "$diff" "$diff_pct"

        COMPARISON_RESULTS[$key]="$status|$baseline_value|$current_value|$diff"
    done

    echo "-------------------------------------------"
    echo ""

    # Generate validation report
    REPORT_FILE="$RESULTS_DIR/validation-report-$TIMESTAMP.txt"

    cat > "$REPORT_FILE" <<EOF
AAP Data Validation Report
============================================
Date: $(date)
Cluster: $CLUSTER_CONTEXT
AAP URL: $AAP_URL
Baseline: $BASELINE_FILE

Validation Results
-------------------------------------------
$(for key in "${!BASELINE_METRICS[@]}"; do
    IFS='|' read -r status baseline_value current_value diff <<< "${COMPARISON_RESULTS[$key]}"
    printf "%-25s %s  %s → %s (diff: %s)\n" "$key" "$status" "$baseline_value" "$current_value" "$diff"
done)
-------------------------------------------

Summary
-------------------------------------------
Total Metrics Checked: ${#BASELINE_METRICS[@]}
Critical Discrepancies: $DISCREPANCIES
Warnings: $WARNINGS

EOF

    if [ $DISCREPANCIES -eq 0 ] && [ $WARNINGS -eq 0 ]; then
        echo "Status: ✅ PASSED" >> "$REPORT_FILE"
        echo "All metrics match baseline exactly." >> "$REPORT_FILE"
        VALIDATION_STATUS="PASSED"
    elif [ $DISCREPANCIES -eq 0 ]; then
        echo "Status: ⚠️  PASSED WITH WARNINGS" >> "$REPORT_FILE"
        echo "Some metrics changed but no data loss detected." >> "$REPORT_FILE"
        VALIDATION_STATUS="PASSED_WITH_WARNINGS"
    else
        echo "Status: ❌ FAILED" >> "$REPORT_FILE"
        echo "Critical discrepancies detected - possible data loss." >> "$REPORT_FILE"
        VALIDATION_STATUS="FAILED"
    fi

    cat >> "$REPORT_FILE" <<EOF

Recommendations
-------------------------------------------
EOF

    if [ $DISCREPANCIES -gt 0 ]; then
        cat >> "$REPORT_FILE" <<EOF
- Investigate data loss for decreased metrics
- Check replication status and lag
- Review failover logs for errors
- Consider restoring from backup if data loss is unacceptable
EOF
    elif [ $WARNINGS -gt 0 ]; then
        cat >> "$REPORT_FILE" <<EOF
- Review increased job counts (expected during normal operations)
- If unexpected changes, investigate potential issues
- Update baseline if this represents new normal state
EOF
    else
        cat >> "$REPORT_FILE" <<EOF
- No action required - validation passed
- Data integrity confirmed post-failover
EOF
    fi

    cat >> "$REPORT_FILE" <<EOF

============================================
Report saved: $REPORT_FILE
EOF

    # Display report
    cat "$REPORT_FILE"

    # Exit with appropriate code
    if [ "$VALIDATION_STATUS" == "PASSED" ]; then
        exit 0
    elif [ "$VALIDATION_STATUS" == "PASSED_WITH_WARNINGS" ]; then
        exit 0
    else
        exit 1
    fi

else
    echo "❌ Invalid action: $ACTION"
    echo "Usage: $0 <create-baseline|validate> <cluster-context>"
    exit 1
fi
