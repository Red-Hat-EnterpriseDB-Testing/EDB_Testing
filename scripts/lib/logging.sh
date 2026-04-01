#!/bin/bash
# Shared Logging Library
# Provides standardized logging functions for AAP DR scripts
#

# Setup logging configuration
# Usage: setup_logging [script-name]
setup_logging() {
    local script_name="${1:-$(basename "${BASH_SOURCE[1]}" .sh)}"

    # Determine log directory
    # Try /var/log first (requires write permission), fall back to /tmp
    if [ -w /var/log ] 2>/dev/null; then
        LOG_DIR="${LOG_DIR:-/var/log/aap-dr}"
        mkdir -p "$LOG_DIR" 2>/dev/null || LOG_DIR="/tmp/aap-dr-logs"
    else
        LOG_DIR="${LOG_DIR:-/tmp/aap-dr-logs}"
    fi

    mkdir -p "$LOG_DIR" 2>/dev/null || {
        echo "ERROR: Cannot create log directory: $LOG_DIR" >&2
        LOG_DIR="/tmp"
    }

    # Create log file with timestamp
    LOG_FILE="$LOG_DIR/${script_name}-$(date +%Y%m%d-%H%M%S).log"
    export LOG_FILE
    export LOG_DIR

    # Create symlink to latest log
    ln -sf "$LOG_FILE" "$LOG_DIR/${script_name}-latest.log" 2>/dev/null || true
}

# Log message with timestamp
# Usage: log "message"
log() {
    local timestamp
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $*" | tee -a "${LOG_FILE:-/dev/null}"
}

# Log message without timestamp (for formatting)
# Usage: log_raw "message"
log_raw() {
    echo "$*" | tee -a "${LOG_FILE:-/dev/null}"
}

# Log error message to stderr and log file
# Usage: log_error "error message"
log_error() {
    local timestamp
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] ERROR: $*" | tee -a "${LOG_FILE:-/dev/null}" >&2
}

# Log warning message
# Usage: log_warn "warning message"
log_warn() {
    local timestamp
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] WARNING: $*" | tee -a "${LOG_FILE:-/dev/null}"
}

# Log info message
# Usage: log_info "info message"
log_info() {
    local timestamp
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] INFO: $*" | tee -a "${LOG_FILE:-/dev/null}"
}

# Log section header
# Usage: log_section "Section Title"
log_section() {
    local title="$1"
    log_raw ""
    log_raw "============================================="
    log_raw "$title"
    log_raw "============================================="
}

# Log success message
# Usage: log_success "success message"
log_success() {
    log "✅ $*"
}

# Log failure message
# Usage: log_failure "failure message"
log_failure() {
    log_error "❌ $*"
}

# Setup cleanup trap
# Usage: setup_cleanup_trap cleanup_function
setup_cleanup_trap() {
    local cleanup_func="$1"

    cleanup_wrapper() {
        local exit_code=$?
        log "Script exiting with code: $exit_code"
        $cleanup_func
        exit $exit_code
    }

    trap cleanup_wrapper EXIT ERR
}

# Rotate old log files (keep last N logs)
# Usage: rotate_logs [script-name] [keep-count]
rotate_logs() {
    local script_name="${1:-$(basename "${BASH_SOURCE[1]}" .sh)}"
    local keep_count="${2:-10}"

    if [ ! -d "$LOG_DIR" ]; then
        return 0
    fi

    # Find and delete old log files
    find "$LOG_DIR" -name "${script_name}-*.log" -type f -mtime +7 -delete 2>/dev/null || true

    # Keep only the last N log files
    ls -t "$LOG_DIR/${script_name}"-*.log 2>/dev/null | tail -n +$((keep_count + 1)) | xargs rm -f 2>/dev/null || true
}
