#!/usr/bin/env bash
#
# Cleanup-CustRunStructure.sh
#
# DANGEROUS SCRIPT – WILL DELETE CUST STRUCTURE UNDER Run
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared libraries
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/config.sh"

# Load configuration
if ! load_config; then
    log_error "Failed to load configuration"
    exit 1
fi

# Normalize VAULT_ROOT path
VAULT_ROOT="${VAULT_ROOT/#\~/$HOME}"
if [[ "$VAULT_ROOT" == *"\\"* ]]; then
    VAULT_ROOT="${VAULT_ROOT//\\//}"
fi

# Safety flags
# ENABLE_CLEANUP is now read from config.json (EnableCleanup field)
# Can be overridden via environment variable
ENABLE_DELETION="${ENABLE_CLEANUP:-false}"
REMOVE_HUB=false        # Set to true if you also want to remove Run-Hub.md
CREATE_BACKUP=true      # Set to true to create backup before deletion (recommended)

#######################################
# Backup function
#######################################

create_backup() {
    local run_path="$1"
    local hub_path="$2"
    
    if [[ ! -d "$run_path" ]]; then
        log_warn "Nothing to backup - Run folder does not exist: $run_path"
        return 0
    fi
    
    # Create backup directory if needed
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_info "Creating backup directory: $BACKUP_DIR"
        mkdir -p "$BACKUP_DIR"
    fi
    
    # Generate timestamp for backup filename
    local timestamp
    timestamp="$(date +"%Y%m%d_%H%M%S")"
    local backup_name="autovault_backup_${timestamp}.tar.gz"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    log_info "Creating backup: $backup_path"
    
    # Build list of items to backup
    local items_to_backup=()
    
    if [[ -d "$run_path" ]]; then
        items_to_backup+=("$run_path")
    fi
    
    if [[ "$REMOVE_HUB" == true && -f "$hub_path" ]]; then
        items_to_backup+=("$hub_path")
    fi
    
    if [[ ${#items_to_backup[@]} -eq 0 ]]; then
        log_warn "No items to backup"
        return 0
    fi
    
    # Create the backup archive
    if tar -czf "$backup_path" "${items_to_backup[@]}" 2>/dev/null; then
        local backup_size
        backup_size="$(du -h "$backup_path" | cut -f1)"
        log_info "Backup created successfully: $backup_path ($backup_size)"
        return 0
    else
        log_error "Failed to create backup archive"
        return 1
    fi
}

#######################################
# Main
#######################################

if [[ "$ENABLE_DELETION" != true ]]; then
    log_error "ABORT: Cleanup disabled. Set EnableCleanup=true in config (cust-run-config.sh config) to enable deletion."
    exit 1
fi

if [[ ${#CUSTOMER_IDS[@]} -eq 0 ]]; then
    log_warn "No CUST ids defined in CUSTOMER_IDS. Nothing to clean."
    exit 0
fi

RUN_PATH="$VAULT_ROOT/Run"
HUB_PATH="$VAULT_ROOT/Run-Hub.md"

# Create backup before deletion if enabled
if [[ "$CREATE_BACKUP" == true ]]; then
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY-RUN] Would create backup before deletion"
    else
        log_info "Backup enabled - creating backup before deletion..."
        if ! create_backup "$RUN_PATH" "$HUB_PATH"; then
            log_error "ABORT: Backup failed. Not proceeding with deletion."
            exit 1
        fi
    fi
else
    log_warn "Backup disabled - proceeding without backup (CREATE_BACKUP=false)"
fi

log_warn "Starting cleanup of CUST folders under: $RUN_PATH"

for id in "${CUSTOMER_IDS[@]}"; do
    if ! [[ "$id" =~ ^[0-9]+$ ]]; then
        log_error "Invalid CUST id (not an integer): $id"
        continue
    fi

    code="$(get_cust_code "$id")"
    cust_root="$RUN_PATH/$code"

    if [[ -d "$cust_root" ]]; then
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_warn "[DRY-RUN] Would remove CUST folder: $cust_root"
        else
            log_warn "Removing CUST folder: $cust_root"
            rm -rf -- "$cust_root"
        fi
    else
        log_debug "CUST folder not found (skip): $cust_root"
    fi
done

if [[ "$REMOVE_HUB" == true ]]; then
    if [[ -f "$HUB_PATH" ]]; then
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_warn "[DRY-RUN] Would remove hub file: $HUB_PATH"
        else
            log_warn "Removing hub file: $HUB_PATH"
            rm -f -- "$HUB_PATH"
        fi
    else
        log_debug "Hub file not found (skip): $HUB_PATH"
    fi
fi

log_info "Cleanup completed."
if [[ "$CREATE_BACKUP" == true ]]; then
    log_info "Backup location: $BACKUP_DIR"
fi
