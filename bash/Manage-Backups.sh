#!/usr/bin/env bash
#
# Manage-Backups.sh - Backup management operations for AutoVault
#
# Usage: Called from cust-run-config.sh
#   bash/Manage-Backups.sh list
#   bash/Manage-Backups.sh restore [BACKUP_FILE]
#
# Depends on: bash/lib/logging.sh, bash/lib/config.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source libraries
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/config.sh"

#--------------------------------------
# LIST BACKUPS
#--------------------------------------
list_backups() {
  local show_all="${1:-false}"
  
  # BACKUP_DIR is set in config.sh
  if [[ ! -d "$BACKUP_DIR" ]]; then
    log_warn "Backup directory does not exist: $BACKUP_DIR"
    return 0
  fi

  local -a backup_files=()
  mapfile -t backup_files < <(find "$BACKUP_DIR" -maxdepth 1 -name "*.json" -type f 2>/dev/null | sort -r)

  if [[ ${#backup_files[@]} -eq 0 ]]; then
    log_info "No backups found in $BACKUP_DIR"
    return 0
  fi

  log_info "Available backups:"
  echo ""
  
  local count=0
  local max_show=10
  
  for backup_file in "${backup_files[@]}"; do
    if [[ "$show_all" != "true" ]] && [[ $count -ge $max_show ]]; then
      local remaining=$((${#backup_files[@]} - max_show))
      echo ""
      log_info "... and $remaining more. Use --all to see all backups."
      break
    fi
    
    local filename
    filename="$(basename "$backup_file")"
    local filesize
    filesize="$(du -h "$backup_file" | cut -f1)"
    local mtime
    mtime="$(stat -c '%y' "$backup_file" 2>/dev/null | cut -d'.' -f1)" || \
    mtime="$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$backup_file" 2>/dev/null)"
    
    # Parse backup filename for metadata if possible
    # Format: cust-run-config.YYYY-MM-DD_HH-MM-SS.json
    if [[ "$filename" =~ cust-run-config\.([0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2})\.json ]]; then
      local backup_time="${BASH_REMATCH[1]//_/ }"
      backup_time="${backup_time//-/:}"
      printf "  %2d. %s  (%s, %s)\n" "$((count + 1))" "$filename" "$filesize" "$backup_time"
    else
      printf "  %2d. %s  (%s)\n" "$((count + 1))" "$filename" "$filesize"
    fi
    
    ((count++))
  done
  
  echo ""
  log_info "Total: ${#backup_files[@]} backup(s) in $BACKUP_DIR"
}

#--------------------------------------
# RESTORE BACKUP
#--------------------------------------
restore_backup() {
  local backup_file="${1:-}"
  
  # BACKUP_DIR is set in config.sh
  if [[ ! -d "$BACKUP_DIR" ]]; then
    log_error "Backup directory does not exist: $BACKUP_DIR"
    return 1
  fi

  if [[ -z "$backup_file" ]]; then
    # Interactive selection
    local -a backup_files=()
    mapfile -t backup_files < <(find "$BACKUP_DIR" -maxdepth 1 -name "*.json" -type f 2>/dev/null | sort -r)
    
    if [[ ${#backup_files[@]} -eq 0 ]]; then
      log_error "No backups found in $BACKUP_DIR"
      return 1
    fi
    
    log_info "Available backups:"
    echo ""
    
    local i=1
    for bf in "${backup_files[@]}"; do
      local filename
      filename="$(basename "$bf")"
      printf "  %2d. %s\n" "$i" "$filename"
      ((i++))
    done
    
    echo ""
    read -rp "Enter backup number to restore (1-${#backup_files[@]}): " choice
    
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#backup_files[@]} ]]; then
      log_error "Invalid selection"
      return 1
    fi
    
    backup_file="${backup_files[$((choice - 1))]}"
  else
    # Check if it's a number (selection from previous list)
    if [[ "$backup_file" =~ ^[0-9]+$ ]]; then
      local -a backup_files=()
      mapfile -t backup_files < <(find "$BACKUP_DIR" -maxdepth 1 -name "*.json" -type f 2>/dev/null | sort -r)
      
      if [[ "$backup_file" -lt 1 ]] || [[ "$backup_file" -gt ${#backup_files[@]} ]]; then
        log_error "Invalid backup number: $backup_file"
        return 1
      fi
      
      backup_file="${backup_files[$((backup_file - 1))]}"
    elif [[ ! "$backup_file" = /* ]]; then
      # Relative path - prepend backup dir
      backup_file="$BACKUP_DIR/$backup_file"
    fi
  fi

  # Validate backup file
  if [[ ! -f "$backup_file" ]]; then
    log_error "Backup file not found: $backup_file"
    return 1
  fi

  # Validate JSON
  if ! jq empty "$backup_file" 2>/dev/null; then
    log_error "Invalid JSON in backup file: $backup_file"
    return 1
  fi

  local filename
  filename="$(basename "$backup_file")"
  
  # Show backup contents
  log_info "Backup file: $filename"
  log_info "Contents:"
  jq -C '.' "$backup_file" 2>/dev/null || jq '.' "$backup_file"
  echo ""
  
  # Confirm restore
  log_warn "This will overwrite the current configuration!"
  
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY-RUN] Would restore configuration from: $filename"
    return 0
  fi
  
  read -rp "Are you sure you want to restore this backup? [y/N]: " confirm
  
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    log_info "Restore cancelled"
    return 0
  fi

  # Backup current config first
  if [[ -f "$CONFIG_JSON" ]]; then
    local timestamp
    timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
    local pre_restore_backup="$BACKUP_DIR/cust-run-config.pre-restore.$timestamp.json"
    mkdir -p "$BACKUP_DIR"
    cp "$CONFIG_JSON" "$pre_restore_backup"
    log_info "Current config backed up to: $(basename "$pre_restore_backup")"
  fi

  # Perform restore
  cp "$backup_file" "$CONFIG_JSON"
  
  log_success "Configuration restored from: $filename"
  
  # Reload and show new config
  load_config
  log_info "New configuration:"
  log_info "  Vault Root: $VAULT_ROOT"
  log_info "  Customers: ${#CUSTOMER_IDS[@]}"
  log_info "  Sections: ${SECTIONS[*]}"
}

#--------------------------------------
# CREATE MANUAL BACKUP
#--------------------------------------
create_backup() {
  local description="${1:-manual}"
  
  if [[ ! -f "$CONFIG_JSON" ]]; then
    log_error "No configuration file to backup: $CONFIG_JSON"
    return 1
  fi

  local timestamp
  timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
  local backup_file="$BACKUP_DIR/cust-run-config.$timestamp.$description.json"
  
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY-RUN] Would create backup: $(basename "$backup_file")"
    return 0
  fi

  mkdir -p "$BACKUP_DIR"
  cp "$CONFIG_JSON" "$backup_file"
  
  log_success "Backup created: $(basename "$backup_file")"
}

#--------------------------------------
# CLEANUP OLD BACKUPS
#--------------------------------------
cleanup_backups() {
  local keep="${1:-10}"
  
  if [[ ! -d "$BACKUP_DIR" ]]; then
    log_info "No backup directory to clean"
    return 0
  fi

  local -a backup_files=()
  mapfile -t backup_files < <(find "$BACKUP_DIR" -maxdepth 1 -name "*.json" -type f 2>/dev/null | sort -r)

  if [[ ${#backup_files[@]} -le $keep ]]; then
    log_info "Only ${#backup_files[@]} backups exist. Nothing to clean."
    return 0
  fi

  local to_delete=$((${#backup_files[@]} - keep))
  
  log_warn "This will delete $to_delete old backup(s), keeping the $keep most recent."
  
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY-RUN] Would delete $to_delete old backup(s):"
    for ((i = keep; i < ${#backup_files[@]}; i++)); do
      log_info "[DRY-RUN]   - $(basename "${backup_files[$i]}")"
    done
    return 0
  fi
  
  read -rp "Continue? [y/N]: " confirm
  
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    log_info "Cleanup cancelled"
    return 0
  fi

  local deleted=0
  for ((i = keep; i < ${#backup_files[@]}; i++)); do
    rm -f "${backup_files[$i]}"
    log_debug "Deleted: $(basename "${backup_files[$i]}")"
    ((deleted++))
  done

  log_success "Deleted $deleted old backup(s)"
}

#--------------------------------------
# MAIN ENTRY POINT
#--------------------------------------
main() {
  local command="${1:-list}"
  shift || true

  # Load config
  load_config

  case "$command" in
    list|ls)
      local show_all=false
      for arg in "$@"; do
        case "$arg" in
          --all|-a) show_all=true ;;
        esac
      done
      list_backups "$show_all"
      ;;
    restore)
      restore_backup "$@"
      ;;
    create|backup)
      create_backup "$@"
      ;;
    cleanup|clean)
      cleanup_backups "$@"
      ;;
    *)
      log_error "Unknown backup command: $command"
      echo "Usage: $0 {list|restore|create|cleanup} [args]" >&2
      return 1
      ;;
  esac
}

# Only run main if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
