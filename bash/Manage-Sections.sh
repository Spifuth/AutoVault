#!/usr/bin/env bash
#
# Manage-Sections.sh - Section management operations for AutoVault
#
# Usage: Called from cust-run-config.sh
#   bash/Manage-Sections.sh add [SECTION]
#   bash/Manage-Sections.sh remove [SECTION]
#   bash/Manage-Sections.sh list
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
# ADD SECTION
#--------------------------------------
add_section() {
  local section="${1:-}"
  
  if [[ -z "$section" ]]; then
    read -rp "Enter section name: " section
  fi

  # Validate non-empty
  if [[ -z "$section" ]]; then
    log_error "Section name cannot be empty"
    return 1
  fi

  # Normalize to uppercase for consistency
  section="${section^^}"

  # Check if already exists
  for existing in "${SECTIONS[@]}"; do
    if [[ "${existing^^}" == "$section" ]]; then
      log_warn "Section '$section' already exists"
      return 0
    fi
  done

  # Confirm addition
  log_info "Adding section '$section' will create new folders for all ${#CUSTOMER_IDS[@]} customers."
  read -rp "Continue? [y/N]: " confirm
  
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    log_info "Cancelled"
    return 0
  fi

  # Add to array
  SECTIONS+=("$section")

  # Save config
  if ensure_config_json; then
    log_success "Added section: $section"
    
    # Create section folders for all customers
    local vault_path="$VAULT_ROOT"
    vault_path="${vault_path/#\~/$HOME}"
    # Convert Windows path to Unix if needed
    if [[ "$vault_path" == *"\\"* ]]; then
      vault_path="${vault_path//\\//}"
    fi
    
    if [[ -d "$vault_path" ]]; then
      log_info "Creating section folders..."
      local created=0
      for id in "${CUSTOMER_IDS[@]}"; do
        local cust_code
        cust_code="$(get_cust_code "$id")"
        local section_dir="$vault_path/Run/$cust_code/$cust_code-$section"
        
        if [[ ! -d "$section_dir" ]]; then
          mkdir -p "$section_dir"
          ((created++))
          log_debug "Created: $section_dir"
        fi
      done
      log_success "Created $created new section folders"
    fi
  else
    log_error "Failed to save configuration"
    return 1
  fi
}

#--------------------------------------
# REMOVE SECTION
#--------------------------------------
remove_section() {
  local section="${1:-}"
  
  if [[ -z "$section" ]]; then
    log_info "Current sections: ${SECTIONS[*]}"
    read -rp "Enter section name to remove: " section
  fi

  # Validate non-empty
  if [[ -z "$section" ]]; then
    log_error "Section name cannot be empty"
    return 1
  fi

  # Normalize for comparison
  local section_upper="${section^^}"

  # Find and remove (case-insensitive)
  local found=false
  local -a new_sections=()
  for existing in "${SECTIONS[@]}"; do
    if [[ "${existing^^}" == "$section_upper" ]]; then
      found=true
    else
      new_sections+=("$existing")
    fi
  done

  if [[ "$found" != true ]]; then
    log_error "Section '$section' not found"
    return 1
  fi

  # Confirm removal
  log_warn "This will remove '$section' from the configuration."
  log_warn "Note: Actual vault folders will NOT be deleted."
  read -rp "Are you sure? [y/N]: " confirm
  
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    log_info "Cancelled"
    return 0
  fi

  # Update array
  SECTIONS=("${new_sections[@]}")

  # Save config
  if ensure_config_json; then
    log_success "Removed section: $section"
  else
    log_error "Failed to save configuration"
    return 1
  fi
}

#--------------------------------------
# LIST SECTIONS
#--------------------------------------
list_sections() {
  local verbose="${1:-false}"

  if [[ ${#SECTIONS[@]} -eq 0 ]]; then
    log_warn "No sections configured"
    return 0
  fi

  log_info "Configured sections:"
  echo ""
  
  if [[ "$verbose" == "true" ]]; then
    local vault_path="$VAULT_ROOT"
    vault_path="${vault_path/#\~/$HOME}"
    # Convert Windows path to Unix if needed
    if [[ "$vault_path" == *"\\"* ]]; then
      vault_path="${vault_path//\\//}"
    fi
    
    for section in "${SECTIONS[@]}"; do
      local existing=0
      local missing=0
      
      for id in "${CUSTOMER_IDS[@]}"; do
        local cust_code
        cust_code="$(get_cust_code "$id")"
        local section_dir="$vault_path/Run/$cust_code/$cust_code-$section"
        
        if [[ -d "$section_dir" ]]; then
          ((existing++))
        else
          ((missing++))
        fi
      done
      
      if [[ $missing -eq 0 ]]; then
        printf "  ${GREEN}✓${RESET} %s (%d/%d customers)\n" "$section" "$existing" "${#CUSTOMER_IDS[@]}"
      else
        printf "  ${YELLOW}!${RESET} %s (%d/%d customers, %d missing)\n" "$section" "$existing" "${#CUSTOMER_IDS[@]}" "$missing"
      fi
    done
  else
    for section in "${SECTIONS[@]}"; do
      printf "  - %s\n" "$section"
    done
  fi
  
  echo ""
  log_info "Total: ${#SECTIONS[@]} sections"
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
    add)
      add_section "$@"
      ;;
    remove|rm|delete)
      remove_section "$@"
      ;;
    list|ls)
      list_sections "${VERBOSE:-false}"
      ;;
    *)
      log_error "Unknown section command: $command"
      echo "Usage: $0 {add|remove|list} [args]" >&2
      return 1
      ;;
  esac
}

# Only run main if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
