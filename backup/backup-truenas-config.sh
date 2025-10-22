#!/bin/bash
#
# Author: Thiago Canozzo Lahr
# Repository: https://github.com/tclahr/homelab
# License: Apache License 2.0
#
# ===============================================================================
# Script Name: backup-truenas-config.sh
#
#  Description:
#    This script creates a backup of the TrueNAS system configuration using the
#    TrueNAS REST API endpoint `/api/v2.0/config/save`.
#
#  Usage:
#    ./backup-truenas-config.sh
#
#  Required Environment Variables:
#    TRUENAS_HOST      - TrueNAS server address or IP (e.g., 192.168.1.100)
#    TRUENAS_PORT      - TrueNAS server HTTP port (default: 80)
#    TRUENAS_API_KEY   - API key generated from the TrueNAS web interface
#    BACKUP_DIR        - Directory where backups will be saved
#    BACKUP_RETAIN     - Number of recent backups to retain (older ones deleted) (default: 30)
#
#  Exit Codes:
#    0 - Success
#    1 - Missing or invalid configuration
#    2 - Backup request failed
#    3 - Download or curl error
#
#  Example:
#    export TRUENAS_HOST="192.168.1.50"
#    export TRUENAS_API_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6..."
#    export BACKUP_DIR="/mnt/backups/truenas"
#    ./backup-truenas-config.sh
#
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Logging function
# -----------------------------------------------------------------------------
log() {
    local level="$1"; shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE:-/dev/null}"
}

# -----------------------------------------------------------------------------
# Validate required environment variables
# -----------------------------------------------------------------------------
if [[ -z "${TRUENAS_HOST:-}" || -z "${TRUENAS_API_KEY:-}" || -z "${BACKUP_DIR:-}" ]]; then
    log "ERROR" "Environment variables TRUENAS_HOST, TRUENAS_API_KEY and BACKUP_DIR must be set."
    log "INFO"  "Example:"
    log "INFO"  "  export TRUENAS_HOST='192.168.1.50'"
    log "INFO"  "  export TRUENAS_API_KEY='eyJhbGciOiJIUzI1NiIsInR5cCI6...'"
    log "INFO"  "  export BACKUP_DIR='/mnt/backups/truenas'"
    log "INFO"  "  export BACKUP_RETAIN=7"
    exit 1
fi

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
LOG_FILE="/var/log/backup-truenas-config.log"
TIMESTAMP=$(date '+%Y%m%d%H%M%S')
BACKUP_FILE="${BACKUP_DIR}/${TRUENAS_HOST}-${TIMESTAMP}.tar"
TRUENAS_PORT="${TRUENAS_PORT:-80}"
BACKUP_RETAIN="${BACKUP_RETAIN:-30}"

# -----------------------------------------------------------------------------
# Prepare backup directory
# -----------------------------------------------------------------------------
if ! mkdir -p "${BACKUP_DIR}"; then
    log "ERROR" "Failed to create or access backup directory: ${BACKUP_DIR}"
    exit 1
fi

# -----------------------------------------------------------------------------
# Run backup
# -----------------------------------------------------------------------------
log "INFO" "Starting TrueNAS configuration backup from ${TRUENAS_HOST}..."
log "INFO" "Output file: ${BACKUP_FILE}"

HTTP_STATUS=$(curl -fsSL -w "%{http_code}" -o "${BACKUP_FILE}" \
    -X POST "http://${TRUENAS_HOST}:${TRUENAS_PORT}/api/v2.0/config/save" \
    -H "accept: */*" \
    -H "Authorization: Bearer ${TRUENAS_API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{}')

# -----------------------------------------------------------------------------
# Handle response
# -----------------------------------------------------------------------------
if [[ "${HTTP_STATUS}" -ne 200 ]]; then
    log "ERROR" "Backup request failed (HTTP ${HTTP_STATUS})."
    rm -f "${BACKUP_FILE}"  # remove incomplete backup
    exit 2
fi

if [[ ! -s "${BACKUP_FILE}" ]]; then
    log "ERROR" "Backup file is empty or missing."
    exit 3
fi

log "INFO" "Backup completed successfully."
log "INFO" "Backup stored at: ${BACKUP_FILE}"

# -----------------------------------------------------------------------------
# Cleanup old backups
# -----------------------------------------------------------------------------
log "INFO" "Checking for old backups to remove (keeping last ${BACKUP_RETAIN})..."

# Find all matching backups sorted by modification time, skip newest N, and delete the rest
OLD_BACKUPS=$(find "${BACKUP_DIR}" -type f -name "*.tar" -printf '%T@ %p\n' | sort -nr | awk "NR>${BACKUP_RETAIN} {print \$2}")

if [[ -n "${OLD_BACKUPS}" ]]; then
    while IFS= read -r old_file; do
        log "INFO" "Deleting old backup: ${old_file}"
        rm -f "${old_file}" || log "WARN" "Failed to delete ${old_file}"
    done <<< "${OLD_BACKUPS}"
else
    log "INFO" "No old backups to remove."
fi

log "INFO" "Backup and cleanup process finished."
exit 0
