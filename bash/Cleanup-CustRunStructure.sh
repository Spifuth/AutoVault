#!/usr/bin/env bash
#
# Cleanup-CustRunStructure.sh
#
set -euo pipefail

# Initialize arrays to avoid unbound variable errors with set -u
declare -a CUSTOMER_IDS=()
declare -a SECTIONS=()

# DANGEROUS SCRIPT – WILL DELETE CUST STRUCTURE UNDER Run
#

#######################################
# Configuration (MUST MATCH SCRIPT 1)
#######################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SH="$SCRIPT_DIR/../cust-run-config.sh"

if [[ ! -f "$CONFIG_SH" ]]; then
    echo "ERROR: cust-run-config.sh not found alongside the cleanup script: $CONFIG_SH" >&2
    exit 1
fi

# shellcheck source=/dev/null
if ! source "$CONFIG_SH"; then
    echo "ERROR: Failed to load configuration from $CONFIG_SH" >&2
    exit 1
fi

# Keep environment exports in sync with PowerShell helpers
export_cust_env

# Safety flags
ENABLE_DELETION=false   # MUST be set to true to delete
REMOVE_HUB=false        # Set to true if you also want to remove Run-Hub.md
CREATE_BACKUP=true      # Set to true to create backup before deletion (recommended)
BACKUP_DIR="${BACKUP_DIR:-"$SCRIPT_DIR/../backups"}"  # Where to store backups

#######################################
# Helper functions
#######################################

write_log() {
    local level="${1:-INFO}"
    shift
    local message="$*"

    local utc localtime
    utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    localtime="$(date +"%Y-%m-%dT%H:%M:%S%z")"

    echo "[$level][UTC:$utc][Local:$localtime] $message"
}

get_cust_code() {
    local id="$1"
    printf "CUST-%0${CUSTOMER_ID_WIDTH}d" "$id"
}

#######################################
# Backup function
#######################################

create_backup() {
    local run_path="$1"
    local hub_path="$2"
    
    if [[ ! -d "$run_path" ]]; then
        write_log "WARN" "Nothing to backup - Run folder does not exist: $run_path"
        return 0
    fi
    
    # Create backup directory if needed
    if [[ ! -d "$BACKUP_DIR" ]]; then
        write_log "INFO" "Creating backup directory: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
    fi
    
    # Generate timestamp for backup filename
    local timestamp
    timestamp="$(date +"%Y%m%d_%H%M%S")"
    local backup_name="autovault_backup_${timestamp}.tar.gz"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    write_log "INFO" "Creating backup: $backup_path"
    
    # Build list of items to backup
    local items_to_backup=()
    
    if [[ -d "$run_path" ]]; then
        items_to_backup+=("$run_path")
    fi
    
    if [[ "$REMOVE_HUB" == true && -f "$hub_path" ]]; then
        items_to_backup+=("$hub_path")
    fi
    
    if [[ ${#items_to_backup[@]} -eq 0 ]]; then
        write_log "WARN" "No items to backup"
        return 0
    fi
    
    # Create the backup archive
    if tar -czf "$backup_path" "${items_to_backup[@]}" 2>/dev/null; then
        local backup_size
        backup_size="$(du -h "$backup_path" | cut -f1)"
        write_log "INFO" "Backup created successfully: $backup_path ($backup_size)"
        return 0
    else
        write_log "ERROR" "Failed to create backup archive"
        return 1
    fi
}

#######################################
# Main
#######################################

if [[ "$ENABLE_DELETION" != true ]]; then
    write_log "ERROR" "ABORT: Cleanup disabled. Set ENABLE_DELETION=true inside the script if you really want to delete."
    exit 1
fi

if [[ ${#CUSTOMER_IDS[@]} -eq 0 ]]; then
    write_log "WARN" "No CUST ids defined in CUSTOMER_IDS. Nothing to clean."
    exit 0
fi

RUN_PATH="$VAULT_ROOT/Run"
HUB_PATH="$VAULT_ROOT/Run-Hub.md"

# Create backup before deletion if enabled
if [[ "$CREATE_BACKUP" == true ]]; then
    write_log "INFO" "Backup enabled - creating backup before deletion..."
    if ! create_backup "$RUN_PATH" "$HUB_PATH"; then
        write_log "ERROR" "ABORT: Backup failed. Not proceeding with deletion."
        exit 1
    fi
else
    write_log "WARN" "Backup disabled - proceeding without backup (CREATE_BACKUP=false)"
fi

write_log "WARN" "Starting cleanup of CUST folders under: $RUN_PATH"

for id in "${CUSTOMER_IDS[@]}"; do
    if ! [[ "$id" =~ ^[0-9]+$ ]]; then
        write_log "ERROR" "Invalid CUST id (not an integer): $id"
        continue
    fi

    code="$(get_cust_code "$id")"
    cust_root="$RUN_PATH/$code"

    if [[ -d "$cust_root" ]]; then
        write_log "WARN" "Removing CUST folder: $cust_root"
        rm -rf -- "$cust_root"
    else
        write_log "DEBUG" "CUST folder not found (skip): $cust_root"
    fi
done

if [[ "$REMOVE_HUB" == true ]]; then
    if [[ -f "$HUB_PATH" ]]; then
        write_log "WARN" "Removing hub file: $HUB_PATH"
        rm -f -- "$HUB_PATH"
    else
        write_log "DEBUG" "Hub file not found (skip): $HUB_PATH"
    fi
fi

write_log "INFO" "Cleanup completed."
if [[ "$CREATE_BACKUP" == true ]]; then
    write_log "INFO" "Backup location: $BACKUP_DIR"
fi
