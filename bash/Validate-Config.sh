#!/usr/bin/env bash
#
# Validate-Config.sh - Configuration validation for AutoVault
#
# Usage: Called from cust-run-config.sh
#   bash/Validate-Config.sh
#   bash/Validate-Config.sh --fix
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
# VALIDATION FUNCTIONS
#--------------------------------------

# Validate JSON syntax
validate_json_syntax() {
  local file="$1"
  
  if [[ ! -f "$file" ]]; then
    log_error "Config file not found: $file"
    return 1
  fi

  if ! jq empty "$file" 2>/dev/null; then
    log_error "Invalid JSON syntax in $file"
    return 1
  fi

  log_debug "JSON syntax: valid"
  return 0
}

# Validate required fields
validate_required_fields() {
  local file="$1"
  local errors=0

  local required_fields=("VaultRoot" "CustomerIdWidth" "CustomerIds" "Sections" "TemplateRelativeRoot")
  
  for field in "${required_fields[@]}"; do
    local value
    value="$(jq -r ".$field // empty" "$file")"
    
    if [[ -z "$value" ]] || [[ "$value" == "null" ]]; then
      log_error "Missing required field: $field"
      ((errors++))
    fi
  done

  if [[ $errors -gt 0 ]]; then
    return 1
  fi

  log_debug "Required fields: all present"
  return 0
}

# Validate field types
validate_field_types() {
  local file="$1"
  local errors=0

  # VaultRoot should be string
  local vault_type
  vault_type="$(jq -r '.VaultRoot | type' "$file")"
  if [[ "$vault_type" != "string" ]]; then
    log_error "VaultRoot must be a string (got: $vault_type)"
    ((errors++))
  fi

  # CustomerIdWidth should be number
  local width_type
  width_type="$(jq -r '.CustomerIdWidth | type' "$file")"
  if [[ "$width_type" != "number" ]]; then
    log_error "CustomerIdWidth must be a number (got: $width_type)"
    ((errors++))
  fi

  # CustomerIds should be array of numbers
  local ids_type
  ids_type="$(jq -r '.CustomerIds | type' "$file")"
  if [[ "$ids_type" != "array" ]]; then
    log_error "CustomerIds must be an array (got: $ids_type)"
    ((errors++))
  else
    local invalid_ids
    invalid_ids="$(jq -r '.CustomerIds[] | select(type != "number")' "$file" 2>/dev/null || true)"
    if [[ -n "$invalid_ids" ]]; then
      log_error "CustomerIds must contain only numbers"
      ((errors++))
    fi
  fi

  # Sections should be array of strings
  local sections_type
  sections_type="$(jq -r '.Sections | type' "$file")"
  if [[ "$sections_type" != "array" ]]; then
    log_error "Sections must be an array (got: $sections_type)"
    ((errors++))
  else
    local invalid_sections
    invalid_sections="$(jq -r '.Sections[] | select(type != "string")' "$file" 2>/dev/null || true)"
    if [[ -n "$invalid_sections" ]]; then
      log_error "Sections must contain only strings"
      ((errors++))
    fi
  fi

  # TemplateRelativeRoot should be string
  local template_type
  template_type="$(jq -r '.TemplateRelativeRoot | type' "$file")"
  if [[ "$template_type" != "string" ]]; then
    log_error "TemplateRelativeRoot must be a string (got: $template_type)"
    ((errors++))
  fi

  if [[ $errors -gt 0 ]]; then
    return 1
  fi

  log_debug "Field types: all correct"
  return 0
}

# Validate field values
validate_field_values() {
  local file="$1"
  local warnings=0

  # CustomerIdWidth should be positive
  local width
  width="$(jq -r '.CustomerIdWidth' "$file")"
  if [[ "$width" -lt 1 ]] || [[ "$width" -gt 10 ]]; then
    log_warn "CustomerIdWidth ($width) should be between 1 and 10"
    ((warnings++))
  fi

  # CustomerIds should not be empty
  local id_count
  id_count="$(jq -r '.CustomerIds | length' "$file")"
  if [[ "$id_count" -eq 0 ]]; then
    log_warn "CustomerIds array is empty"
    ((warnings++))
  fi

  # CustomerIds should not have duplicates
  local unique_count
  unique_count="$(jq -r '.CustomerIds | unique | length' "$file")"
  if [[ "$id_count" -ne "$unique_count" ]]; then
    log_warn "CustomerIds contains duplicate values"
    ((warnings++))
  fi

  # CustomerIds should be positive
  local negative_ids
  negative_ids="$(jq -r '.CustomerIds[] | select(. < 0)' "$file" 2>/dev/null || true)"
  if [[ -n "$negative_ids" ]]; then
    log_warn "CustomerIds contains negative values"
    ((warnings++))
  fi

  # Sections should not be empty
  local section_count
  section_count="$(jq -r '.Sections | length' "$file")"
  if [[ "$section_count" -eq 0 ]]; then
    log_warn "Sections array is empty"
    ((warnings++))
  fi

  # Sections should not have duplicates
  local unique_sections
  unique_sections="$(jq -r '.Sections | unique | length' "$file")"
  if [[ "$section_count" -ne "$unique_sections" ]]; then
    log_warn "Sections contains duplicate values"
    ((warnings++))
  fi

  if [[ $warnings -gt 0 ]]; then
    log_debug "Field values: $warnings warning(s)"
    return 0  # Warnings don't fail validation
  fi

  log_debug "Field values: all valid"
  return 0
}

# Validate vault path exists
validate_vault_path() {
  local file="$1"
  
  local vault_root
  vault_root="$(jq -r '.VaultRoot' "$file")"
  vault_root="${vault_root/#\~/$HOME}"
  
  # Convert Windows path to Unix if needed
  if [[ "$vault_root" == *"\\"* ]]; then
    vault_root="${vault_root//\\//}"
  fi

  if [[ ! -d "$vault_root" ]]; then
    log_warn "VaultRoot directory does not exist: $vault_root"
    return 0  # Warning, not error
  fi

  log_debug "Vault path: exists"
  return 0
}

#--------------------------------------
# FIX FUNCTIONS
#--------------------------------------

fix_duplicates() {
  local file="$1"
  
  log_info "Removing duplicate CustomerIds..."
  local fixed
  fixed="$(jq '.CustomerIds |= unique' "$file")"
  echo "$fixed" > "$file"
  
  log_info "Removing duplicate Sections..."
  fixed="$(jq '.Sections |= unique' "$file")"
  echo "$fixed" > "$file"
  
  log_success "Duplicates removed"
}

fix_sorting() {
  local file="$1"
  
  log_info "Sorting CustomerIds..."
  local fixed
  fixed="$(jq '.CustomerIds |= sort' "$file")"
  echo "$fixed" > "$file"
  
  log_success "CustomerIds sorted"
}

#--------------------------------------
# MAIN VALIDATE
#--------------------------------------
validate_config() {
  local fix="${FIX:-false}"
  local errors=0
  local warnings=0

  echo ""
  log_info "Validating configuration..."
  echo ""

  # Check config file exists
  if [[ ! -f "$CONFIG_JSON" ]]; then
    log_error "Configuration file not found: $CONFIG_JSON"
    log_info "Run 'cust-run-config.sh init' to create a new configuration."
    return 1
  fi

  # Run validations
  echo "Checking JSON syntax..."
  if ! validate_json_syntax "$CONFIG_JSON"; then
    ((errors++))
  fi

  echo "Checking required fields..."
  if ! validate_required_fields "$CONFIG_JSON"; then
    ((errors++))
  fi

  # Only continue if basic validation passed
  if [[ $errors -gt 0 ]]; then
    echo ""
    log_error "Validation failed with $errors error(s)"
    return 1
  fi

  echo "Checking field types..."
  if ! validate_field_types "$CONFIG_JSON"; then
    ((errors++))
  fi

  echo "Checking field values..."
  validate_field_values "$CONFIG_JSON"

  echo "Checking vault path..."
  validate_vault_path "$CONFIG_JSON"

  echo ""
  
  if [[ $errors -gt 0 ]]; then
    log_error "Validation failed with $errors error(s)"
    return 1
  fi

  log_success "Configuration is valid"
  
  # Show config summary
  echo ""
  log_info "Configuration summary:"
  printf "  VaultRoot:          %s\n" "$(jq -r '.VaultRoot' "$CONFIG_JSON")"
  printf "  CustomerIdWidth:    %s\n" "$(jq -r '.CustomerIdWidth' "$CONFIG_JSON")"
  printf "  CustomerIds:        %d entries\n" "$(jq -r '.CustomerIds | length' "$CONFIG_JSON")"
  printf "  Sections:           %d entries\n" "$(jq -r '.Sections | length' "$CONFIG_JSON")"
  printf "  TemplateRoot:       %s\n" "$(jq -r '.TemplateRelativeRoot' "$CONFIG_JSON")"

  # Offer fixes if requested
  if [[ "$fix" == "true" ]]; then
    echo ""
    log_info "Applying fixes..."
    fix_duplicates "$CONFIG_JSON"
    fix_sorting "$CONFIG_JSON"
    log_success "Fixes applied"
  fi

  return 0
}

#--------------------------------------
# MAIN ENTRY POINT
#--------------------------------------
main() {
  # Parse arguments
  for arg in "$@"; do
    case "$arg" in
      --fix|-f) FIX=true ;;
    esac
  done

  # Load config (this also ensures CONFIG_JSON path is set)
  # Don't fail if config doesn't exist - we'll report it in validate
  load_config 2>/dev/null || true

  # Run validation
  validate_config
}

# Only run main if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
