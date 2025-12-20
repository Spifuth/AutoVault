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
# EXPORT CUSTOMER
#--------------------------------------
export_customer() {
  local id="${1:-}"
  local output_file="${2:-}"
  
  if [[ -z "$id" ]]; then
    log_error "Usage: customer export <ID> [output_file]"
    return 1
  fi
  
  # Validate numeric
  if ! [[ "$id" =~ ^[0-9]+$ ]]; then
    log_error "Customer ID must be a positive integer"
    return 1
  fi
  
  # Check if exists
  local found=false
  for existing in "${CUSTOMER_IDS[@]}"; do
    if [[ "$existing" == "$id" ]]; then
      found=true
      break
    fi
  done
  
  if [[ "$found" == "false" ]]; then
    log_error "Customer ID $id not found in configuration"
    return 1
  fi
  
  local cust_code
  cust_code="$(get_cust_code "$id")"
  
  # Normalize vault path
  local vault_path="$VAULT_ROOT"
  vault_path="${vault_path/#\~/$HOME}"
  [[ "$vault_path" == *"\\"* ]] && vault_path="${vault_path//\\//}"
  
  local cust_dir="$vault_path/Run/$cust_code"
  
  if [[ ! -d "$cust_dir" ]]; then
    log_warn "Customer directory not found: $cust_dir"
    log_info "Will export configuration only (no files)"
  fi
  
  # Default output file
  if [[ -z "$output_file" ]]; then
    output_file="${cust_code}-export-$(date +%Y%m%d-%H%M%S).tar.gz"
  fi
  
  # Create temp directory for export
  local temp_dir
  temp_dir=$(mktemp -d)
  local export_dir="$temp_dir/$cust_code"
  mkdir -p "$export_dir"
  
  # Export config
  cat > "$export_dir/customer-config.json" <<EOF
{
  "export_version": "1.0",
  "export_date": "$(date -Iseconds)",
  "customer_id": $id,
  "customer_code": "$cust_code",
  "customer_id_width": $CUSTOMER_ID_WIDTH,
  "sections": $(printf '%s\n' "${SECTIONS[@]}" | jq -R . | jq -s .)
}
EOF
  
  # Copy customer files if they exist
  if [[ -d "$cust_dir" ]]; then
    cp -r "$cust_dir"/* "$export_dir/" 2>/dev/null || true
    log_info "Exported files from $cust_dir"
  fi
  
  # Create archive
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY-RUN] Would create archive: $output_file"
    rm -rf "$temp_dir"
    return 0
  fi
  
  tar -czf "$output_file" -C "$temp_dir" "$cust_code"
  rm -rf "$temp_dir"
  
  local size
  size=$(du -h "$output_file" | cut -f1)
  log_success "Exported $cust_code to: $output_file ($size)"
}

#--------------------------------------
# IMPORT CUSTOMER
#--------------------------------------
import_customer() {
  local archive_file="${1:-}"
  local new_id="${2:-}"
  
  if [[ -z "$archive_file" ]]; then
    log_error "Usage: customer import <archive.tar.gz> [new_id]"
    return 1
  fi
  
  if [[ ! -f "$archive_file" ]]; then
    log_error "Archive file not found: $archive_file"
    return 1
  fi
  
  # Create temp directory for extraction
  local temp_dir
  temp_dir=$(mktemp -d)
  
  # Extract archive
  tar -xzf "$archive_file" -C "$temp_dir"
  
  # Find the customer directory
  local cust_export_dir
  cust_export_dir=$(find "$temp_dir" -maxdepth 1 -type d -name "CUST-*" | head -1)
  
  if [[ -z "$cust_export_dir" ]]; then
    log_error "Invalid archive: no CUST-* directory found"
    rm -rf "$temp_dir"
    return 1
  fi
  
  # Read config
  local config_file="$cust_export_dir/customer-config.json"
  if [[ ! -f "$config_file" ]]; then
    log_error "Invalid archive: customer-config.json not found"
    rm -rf "$temp_dir"
    return 1
  fi
  
  local orig_id
  orig_id=$(jq -r '.customer_id' "$config_file")
  local orig_code
  orig_code=$(jq -r '.customer_code' "$config_file")
  
  log_info "Found exported customer: $orig_code (ID: $orig_id)"
  
  # Determine target ID
  local target_id="${new_id:-$orig_id}"
  
  # Validate numeric
  if ! [[ "$target_id" =~ ^[0-9]+$ ]]; then
    log_error "Target ID must be a positive integer"
    rm -rf "$temp_dir"
    return 1
  fi
  
  # Check if target ID already exists
  for existing in "${CUSTOMER_IDS[@]}"; do
    if [[ "$existing" == "$target_id" ]]; then
      log_warn "Customer ID $target_id already exists"
      printf "Overwrite existing customer? [y/N]: "
      read -r confirm
      if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Import cancelled"
        rm -rf "$temp_dir"
        return 0
      fi
      break
    fi
  done
  
  local target_code
  target_code="$(get_cust_code "$target_id")"
  
  # Normalize vault path
  local vault_path="$VAULT_ROOT"
  vault_path="${vault_path/#\~/$HOME}"
  [[ "$vault_path" == *"\\"* ]] && vault_path="${vault_path//\\//}"
  
  local target_dir="$vault_path/Run/$target_code"
  
  # Dry-run check
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY-RUN] Would import customer as: $target_code"
    log_info "[DRY-RUN] Would copy files to: $target_dir"
    rm -rf "$temp_dir"
    return 0
  fi
  
  # Add to config if not exists
  local id_exists=false
  for existing in "${CUSTOMER_IDS[@]}"; do
    if [[ "$existing" == "$target_id" ]]; then
      id_exists=true
      break
    fi
  done
  
  if [[ "$id_exists" == "false" ]]; then
    CUSTOMER_IDS+=("$target_id")
    mapfile -t CUSTOMER_IDS < <(printf '%s\n' "${CUSTOMER_IDS[@]}" | sort -n)
    ensure_config_json
    log_info "Added customer ID $target_id to configuration"
  fi
  
  # Create target directory
  mkdir -p "$target_dir"
  
  # Copy files, renaming if needed
  if [[ "$orig_code" != "$target_code" ]]; then
    log_info "Renaming from $orig_code to $target_code..."
    
    # Copy and rename files
    for file in "$cust_export_dir"/*; do
      [[ -e "$file" ]] || continue
      local filename
      filename=$(basename "$file")
      
      # Skip config file
      [[ "$filename" == "customer-config.json" ]] && continue
      
      # Replace old code with new code in filenames
      local new_filename="${filename//$orig_code/$target_code}"
      
      if [[ -d "$file" ]]; then
        # Directory - copy and rename
        local new_dir_name="${filename//$orig_code/$target_code}"
        cp -r "$file" "$target_dir/$new_dir_name"
        
        # Rename files inside
        find "$target_dir/$new_dir_name" -type f -name "*$orig_code*" | while read -r f; do
          local new_f="${f//$orig_code/$target_code}"
          mv "$f" "$new_f" 2>/dev/null || true
        done
      else
        # File - copy with new name
        cp "$file" "$target_dir/$new_filename"
      fi
    done
    
    # Replace references inside markdown files
    find "$target_dir" -type f -name "*.md" -exec sed -i "s/$orig_code/$target_code/g" {} \; 2>/dev/null || true
  else
    # Same code, just copy
    cp -r "$cust_export_dir"/* "$target_dir/" 2>/dev/null || true
    rm -f "$target_dir/customer-config.json"
  fi
  
  rm -rf "$temp_dir"
  
  log_success "Imported customer as: $target_code"
  log_info "Files copied to: $target_dir"
}

#--------------------------------------
# CLONE CUSTOMER
#--------------------------------------
clone_customer() {
  local source_id="${1:-}"
  local target_id="${2:-}"
  
  if [[ -z "$source_id" ]] || [[ -z "$target_id" ]]; then
    log_error "Usage: customer clone <source_id> <target_id>"
    return 1
  fi
  
  # Export to temp file
  local temp_archive
  temp_archive=$(mktemp --suffix=.tar.gz)
  
  export_customer "$source_id" "$temp_archive"
  
  if [[ ! -f "$temp_archive" ]]; then
    log_error "Failed to export source customer"
    return 1
  fi
  
  # Import with new ID
  import_customer "$temp_archive" "$target_id"
  
  # Cleanup
  rm -f "$temp_archive"
  
  log_success "Cloned customer $source_id to $target_id"
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
    export)
      export_customer "$@"
      ;;
    import)
      import_customer "$@"
      ;;
    clone|copy|duplicate)
      clone_customer "$@"
      ;;
    *)
      log_error "Unknown customer command: $command"
      echo "Usage: $0 {add|remove|list|export|import|clone} [args]" >&2
      return 1
      ;;
  esac
}

# Only run main if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
