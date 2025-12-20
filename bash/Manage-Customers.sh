#!/usr/bin/env bash
#===============================================================================
#
#  AUTOVAULT - Manage-Customers.sh
#
#===============================================================================
#
#  DESCRIPTION:    Manages customer IDs in the AutoVault configuration.
#                  Allows adding, removing, and listing customer entries.
#                  Automatically creates/removes folder structures.
#
#  COMMANDS:       add <ID>     - Add a new customer ID
#                  remove <ID>  - Remove a customer ID (with confirmation)
#                  list         - List all configured customer IDs
#
#  USAGE:          Called via: ./cust-run-config.sh customer [add|remove|list] [ID]
#                  Direct:     bash/Manage-Customers.sh [command] [args]
#
#  EXAMPLES:       ./cust-run-config.sh customer add 42
#                  ./cust-run-config.sh customer remove 7
#                  ./cust-run-config.sh customer list
#
#  DEPENDENCIES:   bash/lib/logging.sh, bash/lib/config.sh, jq
#
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/config.sh"

#--------------------------------------
# ADD CUSTOMER
#--------------------------------------
add_customer() {
  local id="${1:-}"
  
  if [[ -z "$id" ]]; then
    read -rp "Enter customer ID (number): " id
  fi

  # Validate numeric
  if ! [[ "$id" =~ ^[0-9]+$ ]]; then
    log_error "Customer ID must be a positive integer"
    return 1
  fi

  # Check if already exists
  for existing in "${CUSTOMER_IDS[@]}"; do
    if [[ "$existing" == "$id" ]]; then
      log_warn "Customer ID $id already exists"
      return 0
    fi
  done

  # Add to array
  CUSTOMER_IDS+=("$id")
  
  # Sort the array numerically
  mapfile -t CUSTOMER_IDS < <(printf '%s\n' "${CUSTOMER_IDS[@]}" | sort -n)

  # Dry-run check
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY-RUN] Would add customer ID $id"
    log_info "[DRY-RUN] Would update config file: $CONFIG_JSON"
    return 0
  fi

  # Save config
  if ensure_config_json; then
    log_success "Added customer ID $id"
    
    # Create structure if vault exists
    local vault_path="$VAULT_ROOT"
    vault_path="${vault_path/#\~/$HOME}"
    # Convert Windows path to Unix if needed
    if [[ "$vault_path" == *"\\"* ]]; then
      vault_path="${vault_path//\\//}"
    fi
    
    if [[ -d "$vault_path" ]]; then
      local cust_code
      cust_code="$(get_cust_code "$id")"
      local cust_dir="$vault_path/Run/$cust_code"
      
      if [[ ! -d "$cust_dir" ]]; then
        log_info "Creating directory structure for $cust_code..."
        mkdir -p "$cust_dir"
        for section in "${SECTIONS[@]}"; do
          mkdir -p "$cust_dir/$cust_code-$section"
        done
        # Create index file
        local index_file="$cust_dir/$cust_code-Index.md"
        if [[ ! -f "$index_file" ]]; then
          cat > "$index_file" <<EOF
# $cust_code Index

## Sections
EOF
          for section in "${SECTIONS[@]}"; do
            echo "- [[$cust_code-$section]]" >> "$index_file"
          done
        fi
        log_success "Created structure for $cust_code"
      fi
    fi
  else
    log_error "Failed to save configuration"
    return 1
  fi
}

#--------------------------------------
# REMOVE CUSTOMER
#--------------------------------------
remove_customer() {
  local id="${1:-}"
  
  if [[ -z "$id" ]]; then
    log_info "Current customers: ${CUSTOMER_IDS[*]}"
    read -rp "Enter customer ID to remove: " id
  fi

  # Validate numeric
  if ! [[ "$id" =~ ^[0-9]+$ ]]; then
    log_error "Customer ID must be a positive integer"
    return 1
  fi

  # Find and remove
  local found=false
  local -a new_ids=()
  for existing in "${CUSTOMER_IDS[@]}"; do
    if [[ "$existing" == "$id" ]]; then
      found=true
    else
      new_ids+=("$existing")
    fi
  done

  if [[ "$found" != true ]]; then
    log_error "Customer ID $id not found"
    return 1
  fi

  local cust_code
  cust_code="$(get_cust_code "$id")"

  # Dry-run check
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY-RUN] Would remove customer ID $id ($cust_code)"
    log_info "[DRY-RUN] Would update config file: $CONFIG_JSON"
    return 0
  fi

  # Confirm removal
  log_warn "This will remove $cust_code from the configuration."
  log_warn "Note: Actual vault folders will NOT be deleted."
  read -rp "Are you sure? [y/N]: " confirm
  
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    log_info "Cancelled"
    return 0
  fi

  # Update array
  CUSTOMER_IDS=("${new_ids[@]}")

  # Save config
  if ensure_config_json; then
    log_success "Removed customer ID $id ($cust_code)"
  else
    log_error "Failed to save configuration"
    return 1
  fi
}

#--------------------------------------
# LIST CUSTOMERS
#--------------------------------------
list_customers() {
  local verbose="${1:-false}"

  if [[ ${#CUSTOMER_IDS[@]} -eq 0 ]]; then
    log_warn "No customers configured"
    return 0
  fi

  log_info "Configured customers:"
  echo ""
  
  local vault_path="$VAULT_ROOT"
  vault_path="${vault_path/#\~/$HOME}"
  # Convert Windows path to Unix if needed
  if [[ "$vault_path" == *"\\"* ]]; then
    vault_path="${vault_path//\\//}"
  fi

  for id in "${CUSTOMER_IDS[@]}"; do
    local cust_code
    cust_code="$(get_cust_code "$id")"
    local cust_dir="$vault_path/Run/$cust_code"
    
    if [[ "$verbose" == "true" ]]; then
      if [[ -d "$cust_dir" ]]; then
        printf "  ${GREEN}✓${RESET} %s (%s)\n" "$cust_code" "$cust_dir"
        # Show sections
        for section in "${SECTIONS[@]}"; do
          local section_dir="$cust_dir/$cust_code-$section"
          if [[ -d "$section_dir" ]]; then
            local file_count
            file_count=$(find "$section_dir" -maxdepth 1 -type f 2>/dev/null | wc -l)
            printf "      └─ %s (%d files)\n" "$section" "$file_count"
          else
            printf "      └─ ${YELLOW}%s (missing)${RESET}\n" "$section"
          fi
        done
      else
        printf "  ${YELLOW}?${RESET} %s (directory not found)\n" "$cust_code"
      fi
    else
      printf "  - %s\n" "$cust_code"
    fi
  done
  echo ""
  log_info "Total: ${#CUSTOMER_IDS[@]} customers"
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
      add_customer "$@"
      ;;
    remove|rm|delete)
      remove_customer "$@"
      ;;
    list|ls)
      list_customers "${VERBOSE:-false}"
      ;;
    *)
      log_error "Unknown customer command: $command"
      echo "Usage: $0 {add|remove|list} [args]" >&2
      return 1
      ;;
  esac
}

# Only run main if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
