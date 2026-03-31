#!/bin/bash
#
# Copyright 2026 EnterpriseDB Corporation
#
# DR Test Report Generator
# Generates comprehensive HTML/PDF reports from DR test results
#
# Usage:
#   ./generate-dr-report.sh <test-id>
#   ./generate-dr-report.sh --latest
#

set -e

# Configuration
RESULTS_DIR="/tmp/dr-test-results"
METRICS_DIR="/tmp/dr-metrics"
VALIDATION_DIR="/tmp/aap-validation-results"
REPORTS_DIR="/tmp/dr-reports"

# Parse arguments
TEST_ID="${1:-}"

if [ -z "$TEST_ID" ]; then
    echo "Usage: $0 <test-id> | --latest"
    exit 1
fi

# Handle --latest flag
if [ "$TEST_ID" == "--latest" ]; then
    # Find most recent test
    LATEST_LOG=$(ls -t "$RESULTS_DIR"/dr-test-*.log 2>/dev/null | head -1 || echo "")

    if [ -z "$LATEST_LOG" ]; then
        echo "❌ No test results found in $RESULTS_DIR"
        exit 1
    fi

    TEST_ID=$(basename "$LATEST_LOG" .log)
    echo "Using latest test: $TEST_ID"
fi

# Create reports directory
mkdir -p "$REPORTS_DIR"

# Find test files
TEST_LOG="$RESULTS_DIR/${TEST_ID}.log"
METRICS_FILE="$METRICS_DIR/rto-rpo-${TEST_ID}.json"
VALIDATION_FILE=$(ls -t "$VALIDATION_DIR"/validation-report-*.txt 2>/dev/null | head -1 || echo "")

if [ ! -f "$TEST_LOG" ]; then
    echo "❌ Test log not found: $TEST_LOG"
    exit 1
fi

echo "============================================="
echo "DR Test Report Generator"
echo "============================================="
echo "Test ID: $TEST_ID"
echo "Log file: $TEST_LOG"
echo "Metrics file: $METRICS_FILE"
echo "Validation file: $VALIDATION_FILE"
echo "============================================="
echo ""

# Extract test metadata
TEST_DATE=$(grep "Test ID:" "$TEST_LOG" | head -1 | sed 's/.*\[\([^]]*\)\].*/\1/' || date)
DC1_CONTEXT=$(grep "DC1 Context:" "$TEST_LOG" | head -1 | awk '{print $NF}' || echo "unknown")
DC2_CONTEXT=$(grep "DC2 Context:" "$TEST_LOG" | head -1 | awk '{print $NF}' || echo "unknown")

# Extract RTO/RPO if available
if [ -f "$METRICS_FILE" ]; then
    RTO=$(grep '"rto_seconds"' "$METRICS_FILE" | grep -o '[0-9.]*' || echo "N/A")
    RTO_MINUTES=$(awk "BEGIN {printf \"%.2f\", $RTO / 60}" 2>/dev/null || echo "N/A")
else
    RTO="N/A"
    RTO_MINUTES="N/A"
fi

# Determine test status
if grep -q "✅ COMPLETED" "$TEST_LOG"; then
    TEST_STATUS="PASSED"
    STATUS_EMOJI="✅"
elif grep -q "❌" "$TEST_LOG"; then
    TEST_STATUS="FAILED"
    STATUS_EMOJI="❌"
else
    TEST_STATUS="INCOMPLETE"
    STATUS_EMOJI="⚠️"
fi

# Generate Markdown report
REPORT_FILE="$REPORTS_DIR/${TEST_ID}-report.md"

cat > "$REPORT_FILE" <<EOF
# Disaster Recovery Test Report

**Test ID:** $TEST_ID
**Date:** $TEST_DATE
**Status:** $STATUS_EMOJI $TEST_STATUS

---

## Executive Summary

This report summarizes the disaster recovery failover test conducted on $TEST_DATE. The test simulated a complete failure of DC1 (primary datacenter) and validated the automated failover to DC2 (standby datacenter).

### Key Results

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| **RTO (Recovery Time)** | < 5 minutes | ${RTO}s (${RTO_MINUTES} min) | $(if (( $(awk "BEGIN {print ($RTO <= 300)}" 2>/dev/null || echo 0) )); then echo "✅ PASS"; else echo "❌ FAIL"; fi) |
| **RPO (Data Loss)** | < 5 seconds | See validation | ℹ️ Manual |
| **Data Integrity** | 100% | See validation | $([ -f "$VALIDATION_FILE" ] && echo "✅ CHECKED" || echo "⚠️ N/A") |
| **AAP Availability** | Restored | $(grep -q "AAP API responding" "$TEST_LOG" && echo "✅ YES" || echo "⚠️ PARTIAL") | - |

---

## Test Execution Timeline

$(if [ -f "$METRICS_FILE" ]; then
    echo "### Milestones"
    echo ""
    echo "| Milestone | Elapsed Time | Timestamp |"
    echo "|-----------|--------------|-----------|"

    # Extract milestones from JSON
    grep -A 4 '"milestones"' "$METRICS_FILE" | grep -E '"elapsed_seconds"|"timestamp"' | while IFS= read -r line; do
        if echo "$line" | grep -q '"elapsed_seconds"'; then
            milestone_name=$(echo "$line" | sed 's/.*"\([^"]*\)".*/\1/')
            elapsed=$(echo "$line" | grep -o '[0-9.]*')
            timestamp=$(echo "$line" | grep -o '[0-9-]* [0-9:]*')

            printf "| %s | %.2fs | %s |\n" "$milestone_name" "$elapsed" "$timestamp"
        fi
    done
else
    echo "Metrics file not available."
fi)

---

## Test Phases

### Phase 1: Pre-flight Checks

$(grep -A 20 "Phase 1: Pre-flight Checks" "$TEST_LOG" | grep "✓\|✅\|⚠️\|❌" | sed 's/\[.*\] /- /')

### Phase 2: Baseline Creation

$(grep -A 10 "Phase 2: Create Data Baseline" "$TEST_LOG" | grep "✓\|✅\|⚠️\|❌" | sed 's/\[.*\] /- /')

### Phase 3: Failover Simulation

$(grep -A 30 "Phase 3: Simulate DC1 Failure" "$TEST_LOG" | grep "✓\|✅\|⚠️\|❌" | sed 's/\[.*\] /- /')

### Phase 4: Validation

$(grep -A 20 "Phase 4: Validate Failover" "$TEST_LOG" | grep "✓\|✅\|⚠️\|❌" | sed 's/\[.*\] /- /')

---

## Data Validation Results

$(if [ -f "$VALIDATION_FILE" ]; then
    cat "$VALIDATION_FILE"
else
    echo "Validation report not available."
fi)

---

## Issues & Observations

### Successes

$(grep "✅" "$TEST_LOG" | sed 's/\[.*\] /- /' | head -10)

### Warnings

$(grep "⚠️" "$TEST_LOG" | sed 's/\[.*\] /- /' | head -10)

### Errors

$(grep "❌" "$TEST_LOG" | sed 's/\[.*\] /- /' | head -10)

---

## Recommendations

### Immediate Actions

$(if [ "$TEST_STATUS" == "FAILED" ]; then
    echo "1. **CRITICAL**: Investigate test failures before next drill"
    echo "2. Review error logs and resolve root causes"
    echo "3. Re-test failover procedures after fixes"
else
    echo "1. Review test metrics and update baselines"
    echo "2. Document any deviations from expected behavior"
    echo "3. Update runbooks based on actual timings"
fi)

### Process Improvements

- [ ] Update DR runbooks with actual RTO measurements
- [ ] Review and tune alert thresholds if needed
- [ ] Schedule next quarterly DR drill
- [ ] Train on-call engineers on failover procedures

### Technical Improvements

$(if (( $(awk "BEGIN {print ($RTO > 300)}" 2>/dev/null || echo 0) )); then
    echo "- [ ] Investigate RTO exceeding target (${RTO}s > 300s)"
    echo "- [ ] Optimize failover automation to reduce recovery time"
fi)

- [ ] Implement automated failback procedures
- [ ] Add more granular RTO/RPO tracking
- [ ] Deploy replication monitoring (if not already done)

---

## Appendix

### Test Configuration

- **DC1 Cluster:** $DC1_CONTEXT
- **DC2 Cluster:** $DC2_CONTEXT
- **Test Type:** Automated failover simulation
- **Failback:** $(grep -q "skip-failback" "$TEST_LOG" && echo "Skipped" || echo "Attempted")

### Files Generated

- **Test Log:** \`$TEST_LOG\`
- **RTO/RPO Metrics:** \`$METRICS_FILE\`
- **Validation Report:** \`$VALIDATION_FILE\`
- **This Report:** \`$REPORT_FILE\`

### Full Test Log

<details>
<summary>Click to expand full test log</summary>

\`\`\`
$(cat "$TEST_LOG")
\`\`\`

</details>

---

**Report Generated:** $(date)
**Generator Version:** 1.0
**Repository:** EDB_Testing

EOF

echo "✅ Report generated: $REPORT_FILE"
echo ""

# Generate plain text summary
SUMMARY_FILE="$REPORTS_DIR/${TEST_ID}-summary.txt"

cat > "$SUMMARY_FILE" <<EOF
============================================
DR TEST SUMMARY - $TEST_ID
============================================

Date: $TEST_DATE
Status: $TEST_STATUS

RTO: ${RTO}s (${RTO_MINUTES} minutes)
Target: 300s (5 minutes)
Result: $(if (( $(awk "BEGIN {print ($RTO <= 300)}" 2>/dev/null || echo 0) )); then echo "PASSED"; else echo "FAILED"; fi)

DC1: $DC1_CONTEXT
DC2: $DC2_CONTEXT

============================================
KEY FINDINGS
============================================

$(grep "✅\|✓" "$TEST_LOG" | wc -l) Successes
$(grep "⚠️" "$TEST_LOG" | wc -l) Warnings
$(grep "❌" "$TEST_LOG" | wc -l) Errors

============================================
NEXT STEPS
============================================

1. Review full report: $REPORT_FILE
2. Address any warnings or errors
3. Update DR documentation
4. Schedule next test

============================================
EOF

echo "✅ Summary generated: $SUMMARY_FILE"
echo ""

# Display summary
cat "$SUMMARY_FILE"

echo ""
echo "📊 Reports available:"
echo "  - Detailed Markdown: $REPORT_FILE"
echo "  - Quick Summary: $SUMMARY_FILE"
echo ""

exit 0
