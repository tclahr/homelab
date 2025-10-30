#!/bin/bash
#
# Author: Thiago Canozzo Lahr
# Repository: https://github.com/tclahr/homelab
# License: Apache License 2.0
#
#===============================================================================
# Script Name: backup-proxmox-host-config.sh
#
# Description:
#   Creates a backup of Proxmox host configuration files (`/etc/pve` and `/etc/network`)
#   and uploads them to a Proxmox Backup Server (PBS) repository using
#   `proxmox-backup-client`.
#
#   Designed for manual or scheduled (cron) execution.
#
# Usage:
#   1. Export the required environment variables:
#        export PBS_REPOSITORY='backup@pbs!api@host:ProxmoxBackupServer'
#        export PBS_PASSWORD='69344598-....'
#
#   2. Run manually:
#        bash backup-proxmox-host-config.sh
#
#   3. Or via cron (example below):
#        0 0 * * * export PBS_REPOSITORY='...' && \
#        export PBS_PASSWORD='...' && \
#        bash -c "$(curl -fsSL https://raw.githubusercontent.com/tclahr/homelab/main/backup/backup-proxmox-host-config.sh)"
#
# Requirements:
#   - `proxmox-backup-client` must be installed and in $PATH.
#   - Environment variables `PBS_REPOSITORY` and `PBS_PASSWORD` must be defined.
#
# Logging:
#   - Logs are written to /var/log/proxmox-host-backup.log
#   - Includes both stdout and stderr with timestamps.
#===============================================================================

#------------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------------

LOG_FILE="/var/log/backup-proxmox-host-config.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Redirect stdout and stderr to log file with timestamps
exec > >(while IFS= read -r line; do echo "$(date '+%F %T') [INFO] $line"; done | tee -a "$LOG_FILE") \
     2> >(while IFS= read -r line; do echo "$(date '+%F %T') [ERROR] $line"; done | tee -a "$LOG_FILE" >&2)

# Stop on errors, unset variables, or failed pipes
set -euo pipefail

#------------------------------------------------------------------------------
# Helper Functions
#------------------------------------------------------------------------------

log() {
  echo "$(date '+%F %T') [INFO] $*"
}

error_exit() {
  echo "$(date '+%F %T') [ERROR] $*" >&2
  exit 1
}

check_requirements() {
  command -v proxmox-backup-client >/dev/null 2>&1 || error_exit "proxmox-backup-client not found. Please install it."
  [[ -n "${PBS_REPOSITORY:-}" ]] || error_exit "PBS_REPOSITORY environment variable not set."
  [[ -n "${PBS_PASSWORD:-}" ]] || error_exit "PBS_PASSWORD environment variable not set."
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

log "Starting Proxmox host configuration backup..."

check_requirements

HOSTNAME=$(hostname)
DATE=$(date +%F)
BACKUP_ID="proxmox-host-config-${HOSTNAME}"

log "Hostname: ${HOSTNAME}"
log "Date: ${DATE}"
log "Repository: ${PBS_REPOSITORY}"
log "Backup ID: ${BACKUP_ID}"

# Perform backup
if proxmox-backup-client backup \
  etc-"${DATE}".pxar:/etc \
  crontabs-"${DATE}".pxar:/var/spool/cron \
  --repository "${PBS_REPOSITORY}" \
  --backup-id "${BACKUP_ID}"
then
  log "Backup completed successfully."
else
  error_exit "Backup failed. Check ${LOG_FILE} for details."
fi

log "Backup process finished."
exit 0

#------------------------------------------------------------------------------
# End of Script
#------------------------------------------------------------------------------
