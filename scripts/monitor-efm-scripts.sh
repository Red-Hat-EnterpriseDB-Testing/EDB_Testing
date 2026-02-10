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
# Monitor EFM Script Execution
# This script checks the status of EFM failover script executions
#

LOGFILE="/var/log/efm-aap-failover.log"
ORCHESTRATED_LOGFILE="/var/log/efm-orchestrated-failover.log"

echo "========================================"
echo "EFM Script Execution Monitor"
echo "========================================"
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Check if log file exists
if [ ! -f "$LOGFILE" ]; then
    echo "❌ Log file not found: $LOGFILE"
    echo "No EFM failover executions recorded"
    exit 0
fi

# Get last execution timestamp
LAST_EXECUTION=$(grep "EFM AAP Failover Script Triggered" "$LOGFILE" | tail -1)

if [ -z "$LAST_EXECUTION" ]; then
    echo "ℹ️  No EFM failover script executions found"
    exit 0
fi

echo "Last Execution:"
echo "$LAST_EXECUTION"
echo ""

# Extract details from last execution
CLUSTER_NAME=$(grep -A 10 "EFM AAP Failover Script Triggered" "$LOGFILE" | tail -11 | grep "Cluster:" | tail -1 | cut -d: -f2 | xargs)
NODE_TYPE=$(grep -A 10 "EFM AAP Failover Script Triggered" "$LOGFILE" | tail -11 | grep "Node Type:" | tail -1 | cut -d: -f2 | xargs)
NODE_ADDRESS=$(grep -A 10 "EFM AAP Failover Script Triggered" "$LOGFILE" | tail -11 | grep "Node Address:" | tail -1 | cut -d: -f2 | xargs)
DATACENTER=$(grep -A 10 "EFM AAP Failover Script Triggered" "$LOGFILE" | tail -11 | grep "Detected Datacenter:" | tail -1 | cut -d: -f2 | xargs)

echo "Execution Details:"
echo "  Cluster: $CLUSTER_NAME"
echo "  Node Type: $NODE_TYPE"
echo "  Node Address: $NODE_ADDRESS"
echo "  Datacenter: $DATACENTER"
echo ""

# Check execution status
if grep -q "AAP cluster scaled up successfully" "$LOGFILE"; then
    LAST_SUCCESS=$(grep "AAP cluster scaled up successfully" "$LOGFILE" | tail -1)
    echo "✅ Status: SUCCESS"
    echo "   $LAST_SUCCESS"
    EXIT_STATUS=0
else
    LAST_ERROR=$(grep -E "ERROR|FAILED|✗" "$LOGFILE" | tail -1)
    echo "❌ Status: FAILED"
    if [ -n "$LAST_ERROR" ]; then
        echo "   Error: $LAST_ERROR"
    fi
    EXIT_STATUS=1
fi

echo ""

# Count total executions
TOTAL_EXECUTIONS=$(grep -c "EFM AAP Failover Script Triggered" "$LOGFILE" 2>/dev/null || echo 0)
SUCCESSFUL_EXECUTIONS=$(grep -c "AAP cluster scaled up successfully" "$LOGFILE" 2>/dev/null || echo 0)
FAILED_EXECUTIONS=$((TOTAL_EXECUTIONS - SUCCESSFUL_EXECUTIONS))

echo "Statistics:"
echo "  Total Executions: $TOTAL_EXECUTIONS"
echo "  Successful: $SUCCESSFUL_EXECUTIONS"
echo "  Failed: $FAILED_EXECUTIONS"

# Calculate success rate
if [ "$TOTAL_EXECUTIONS" -gt 0 ]; then
    SUCCESS_RATE=$(awk "BEGIN {printf \"%.1f\", ($SUCCESSFUL_EXECUTIONS/$TOTAL_EXECUTIONS)*100}")
    echo "  Success Rate: ${SUCCESS_RATE}%"
fi

echo ""

# Show recent execution history (last 5)
echo "Recent Execution History:"
grep "EFM AAP Failover Script Triggered\|AAP cluster scaled up successfully\|ERROR" "$LOGFILE" | tail -10

echo ""
echo "========================================"

# Check orchestrated failover log if it exists
if [ -f "$ORCHESTRATED_LOGFILE" ]; then
    echo ""
    echo "Orchestrated Failover Status:"
    echo "------------------------------"
    
    ORCHESTRATED_LAST=$(grep "Starting orchestrated failover" "$ORCHESTRATED_LOGFILE" | tail -1)
    if [ -n "$ORCHESTRATED_LAST" ]; then
        echo "$ORCHESTRATED_LAST"
        
        if grep -q "Orchestrated failover complete" "$ORCHESTRATED_LOGFILE"; then
            echo "✅ Last orchestrated failover: SUCCESS"
        else
            echo "❌ Last orchestrated failover: IN PROGRESS or FAILED"
        fi
    fi
fi

echo ""
echo "Log Locations:"
echo "  Main Log: $LOGFILE"
echo "  Orchestrated Log: $ORCHESTRATED_LOGFILE"
echo "  EFM Log: /var/log/efm-4.x/efm-startup.log"
echo ""

exit $EXIT_STATUS
