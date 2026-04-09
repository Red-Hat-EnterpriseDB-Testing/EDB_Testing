# Scripts Library Reference

This document provides detailed reference for shared library functions used across AAP DR scripts.

## Overview

The `scripts/lib/` directory contains reusable Bash libraries that provide common functionality:

- **aap-scaling.sh** - Ansible Automation Platform (AAP) deployment scaling and validation functions
- **logging.sh** - Standardized logging and output formatting

## aap-scaling.sh

Location: `scripts/lib/aap-scaling.sh`

### Purpose

Provides common functions for scaling AAP deployments across different datacenter environments with safety checks and validation.

### Global Variables

#### AAP_DEPLOYMENTS

Associative array defining AAP deployments and their operational replica counts:

```bash
declare -gA AAP_DEPLOYMENTS=(
    ["aap-gateway"]="3"
    ["automation-controller-operator-controller-manager"]="1"
    ["automation-controller-task"]="3"
    ["automation-controller-web"]="3"
    ["automation-hub-operator-controller-manager"]="1"
    ["automation-hub-api"]="2"
    ["automation-hub-content"]="2"
    ["automation-hub-worker"]="2"
)
```

### Functions

#### validate_cluster_context

Validates that a cluster context is not a placeholder value.

**Usage:**
```bash
validate_cluster_context <context>
```

**Parameters:**
- `context` - Cluster context name to validate

**Returns:**
- `0` - Valid context
- `1` - Invalid or placeholder context

**Example:**
```bash
if ! validate_cluster_context "$CLUSTER_CONTEXT"; then
    exit 1
fi
```

**Validation Checks:**
- Context is not empty
- Context doesn't contain "your-" prefix
- Context doesn't contain "example"

---

#### get_current_replicas

Retrieves the current replica count for a deployment.

**Usage:**
```bash
get_current_replicas <deployment> <namespace>
```

**Parameters:**
- `deployment` - Deployment name
- `namespace` - Kubernetes namespace

**Returns:**
- Current replica count (stdout)
- "0" if deployment doesn't exist

**Example:**
```bash
current=$(get_current_replicas "aap-gateway" "ansible-automation-platform")
echo "Current replicas: $current"
```

---

#### needs_scaling

Checks if a deployment needs to be scaled (idempotency check).

**Usage:**
```bash
needs_scaling <deployment> <namespace> <target-replicas>
```

**Parameters:**
- `deployment` - Deployment name
- `namespace` - Kubernetes namespace
- `target-replicas` - Target replica count

**Returns:**
- `0` - Scaling is needed
- `1` - Already at target (no scaling needed)

**Example:**
```bash
if needs_scaling "aap-gateway" "ansible-automation-platform" 3; then
    echo "Scaling is required"
else
    echo "Already at target replica count"
fi
```

---

#### validate_database_primary

**CRITICAL SAFETY FUNCTION**

Validates that the database is in primary mode before allowing AAP scaling. This prevents split-brain scenarios where AAP connects to a read-only replica.

**Usage:**
```bash
validate_database_primary <db-namespace> <db-cluster>
```

**Parameters:**
- `db-namespace` - Database namespace
- `db-cluster` - Database cluster name

**Returns:**
- `0` - Database is primary (safe to scale AAP)
- `1` - Database is replica or unavailable (DO NOT scale AAP)

**Example:**
```bash
if ! validate_database_primary "edb-postgres" "postgresql"; then
    echo "CRITICAL: Database is not primary. Aborting AAP scale-up."
    exit 1
fi
```

**How It Works:**

1. Queries Kubernetes for pod with label: `cnpg.io/cluster=$db_cluster,role=primary`
2. Executes `SELECT pg_is_in_recovery()` against the database
3. Returns:
   - `f` (false) = Primary database ✅
   - `t` (true) = Replica database ❌
   - Empty/error = Cannot determine ⚠️

**Safety Guarantees:**

- Prevents scaling AAP against a read-only replica
- Blocks split-brain scenarios (AAP in DC1 + DC2 simultaneously)
- Ensures data integrity during failover operations

---

#### wait_for_pods

Waits for AAP pods to reach ready state with configurable timeout.

**Usage:**
```bash
wait_for_pods <namespace> <min-ready-count> <timeout>
```

**Parameters:**
- `namespace` - Kubernetes namespace
- `min-ready-count` - Minimum number of ready pods (default: 10)
- `timeout` - Timeout in seconds (default: 300)

**Returns:**
- `0` - Pods are ready
- `1` - Timeout exceeded

**Example:**
```bash
if wait_for_pods "ansible-automation-platform" 10 300; then
    echo "AAP is ready"
else
    echo "WARNING: Pods not ready after timeout"
fi
```

**Monitoring Logic:**

- Polls every 10 seconds
- Counts pods matching pattern: `automation-(controller|hub)|aap-gateway`
- Checks for ready state: `1/1`, `2/2`, or `3/3`
- Displays progress: `Ready pods: X / Y (elapsed: Zs)`

---

#### scale_deployment

Scales a deployment with idempotency and error handling.

**Usage:**
```bash
scale_deployment <deployment> <namespace> <target-replicas>
```

**Parameters:**
- `deployment` - Deployment name
- `namespace` - Kubernetes namespace
- `target-replicas` - Target replica count

**Returns:**
- `0` - Successfully scaled or already at target
- `1` - Scaling failed

**Example:**
```bash
if scale_deployment "aap-gateway" "ansible-automation-platform" 3; then
    echo "Deployment scaled successfully"
fi
```

**Features:**

- Checks if deployment exists (skips if not found)
- Idempotent: skips if already at target replica count
- Logs current → target transition
- Uses `oc scale deployment` command

---

## logging.sh

Location: `scripts/lib/logging.sh`

### Purpose

Provides standardized logging functions with timestamp formatting, log rotation, and multiple output levels.

### Functions

#### setup_logging

Initializes logging configuration and creates log file.

**Usage:**
```bash
setup_logging [script-name]
```

**Parameters:**
- `script-name` - Optional script name (defaults to calling script's basename)

**Environment Variables Set:**
- `LOG_FILE` - Full path to log file
- `LOG_DIR` - Log directory path

**Example:**
```bash
setup_logging "my-script"
# Creates: /var/log/aap-dr/my-script-20260403-143000.log
# Symlink: /var/log/aap-dr/my-script-latest.log
```

**Log Directory Priority:**
1. `/var/log/aap-dr` (if writable)
2. `/tmp/aap-dr-logs` (fallback)
3. `/tmp` (last resort)

---

#### log

Logs a timestamped message to stdout and log file.

**Usage:**
```bash
log "message"
```

**Output Format:**
```
[2026-04-03 14:30:00] message
```

---

#### log_raw

Logs a message without timestamp (for formatting/headers).

**Usage:**
```bash
log_raw "message"
```

---

#### log_error

Logs an error message to stderr and log file.

**Usage:**
```bash
log_error "error message"
```

**Output Format:**
```
[2026-04-03 14:30:00] ERROR: error message
```

---

#### log_warn

Logs a warning message.

**Usage:**
```bash
log_warn "warning message"
```

**Output Format:**
```
[2026-04-03 14:30:00] WARNING: warning message
```

---

#### log_info

Logs an informational message.

**Usage:**
```bash
log_info "info message"
```

**Output Format:**
```
[2026-04-03 14:30:00] INFO: info message
```

---

#### log_section

Logs a formatted section header.

**Usage:**
```bash
log_section "Section Title"
```

**Output Format:**
```

=============================================
Section Title
=============================================
```

---

#### log_success

Logs a success message with checkmark emoji.

**Usage:**
```bash
log_success "operation completed"
```

**Output:**
```
[2026-04-03 14:30:00] ✅ operation completed
```

---

#### log_failure

Logs a failure message with X emoji.

**Usage:**
```bash
log_failure "operation failed"
```

**Output:**
```
[2026-04-03 14:30:00] ERROR: ❌ operation failed
```

---

#### setup_cleanup_trap

Sets up EXIT/ERR trap for cleanup operations.

**Usage:**
```bash
setup_cleanup_trap cleanup_function
```

**Example:**
```bash
cleanup() {
    log "Cleaning up temporary files..."
    rm -f /tmp/my-temp-file
}

setup_cleanup_trap cleanup
```

---

#### rotate_logs

Rotates old log files to prevent disk space issues.

**Usage:**
```bash
rotate_logs [script-name] [keep-count]
```

**Parameters:**
- `script-name` - Script name (defaults to calling script)
- `keep-count` - Number of logs to keep (default: 10)

**Example:**
```bash
rotate_logs "my-script" 5
# Keeps only the 5 most recent log files
```

**Rotation Logic:**
- Deletes logs older than 7 days
- Keeps only the last N log files (by modification time)
- Runs silently (errors suppressed)

---

## Usage Examples

### Complete Script Template

```bash
#!/bin/bash
set -euo pipefail

# Load libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/aap-scaling.sh"

# Setup logging
setup_logging "my-dr-script"

# Define cleanup
cleanup() {
    log "Cleanup complete"
}
setup_cleanup_trap cleanup

# Main script
log_section "Starting DR Operation"

CLUSTER_CONTEXT="${1:-}"
if ! validate_cluster_context "$CLUSTER_CONTEXT"; then
    log_failure "Invalid cluster context"
    exit 1
fi

log_info "Validating database..."
if ! validate_database_primary "edb-postgres" "postgresql"; then
    log_failure "Database is not primary - aborting"
    exit 1
fi

log_success "Pre-flight checks passed"

log_info "Scaling AAP deployments..."
for deployment in "${!AAP_DEPLOYMENTS[@]}"; do
    target=${AAP_DEPLOYMENTS[$deployment]}
    scale_deployment "$deployment" "ansible-automation-platform" "$target"
done

log_success "Operation complete"
rotate_logs "my-dr-script" 10
```

### Quick One-Liner Examples

```bash
# Source library and use directly
source scripts/lib/aap-scaling.sh
validate_cluster_context "my-cluster" && echo "Valid"

# Check if scaling is needed
source scripts/lib/aap-scaling.sh
if needs_scaling "aap-gateway" "ansible-automation-platform" 3; then
    echo "Scaling required"
fi

# Quick logging
source scripts/lib/logging.sh
setup_logging "test"
log_success "This worked!"
log_error "This failed!"
```

## Best Practices

1. **Always source libraries at the beginning** of scripts
2. **Use `validate_database_primary`** before any AAP scaling operation
3. **Call `setup_logging`** early to capture all output
4. **Use `setup_cleanup_trap`** for proper resource cleanup
5. **Check return codes** of validation functions
6. **Rotate logs regularly** to prevent disk space issues

## Error Handling

All library functions follow this convention:

- Return `0` on success
- Return `1` on failure
- Write errors to stderr
- Log errors to log file (if logging enabled)

Scripts should check return codes:

```bash
if ! validate_database_primary "edb-postgres" "postgresql"; then
    log_failure "Database validation failed"
    exit 1
fi
```

## See Also

- [Scripts Guide](scripts-guide.md) - Complete scripts documentation
- [DR Testing Guide](dr-testing-guide.md) - DR testing procedures
- [Split-Brain Prevention](split-brain-prevention.md) - Split-brain prevention details
