#!/usr/bin/env bash
#
# Show-Status.sh - Display comprehensive status for AutoVault
#
# Usage: Called from cust-run-config.sh
#   bash/Show-Status.sh
#   bash/Show-Status.sh --verbose
#
# Depends on: bash/lib/logging.sh, bash/lib/config.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/config.sh"

#--------------------------------------
# STATUS DISPLAY
#--------------------------------------
# shellcheck disable=SC2059  # Variables in printf format are intentional for ANSI colors
show_status() {
  local verbose="${VERBOSE:-false}"

  echo ""
  echo "═══════════════════════════════════════════════════════════════"
  echo "                    AutoVault Status Report                     "
  echo "═══════════════════════════════════════════════════════════════"
  echo ""

  #--------------------------------------
  # Configuration
  #--------------------------------------
  printf "${BOLD}Configuration${RESET}\n"
  echo "─────────────────────────────────────────────────────────────────"
  
  local config_display
  config_display="$(realpath "$CONFIG_JSON" 2>/dev/null || echo "$CONFIG_JSON")"
  
  if [[ -f "$CONFIG_JSON" ]]; then
    printf "  Config File:        ${GREEN}✓${RESET} %s\n" "$config_display"
  else
    printf "  Config File:        ${RED}✗${RESET} %s (not found)\n" "$config_display"
  fi
  
  printf "  Vault Root:         %s\n" "$VAULT_ROOT"
  printf "  Customer ID Width:  %s\n" "$CUSTOMER_ID_WIDTH"
  printf "  Template Root:      %s\n" "$TEMPLATE_RELATIVE_ROOT"
  echo ""

  #--------------------------------------
  # Vault Status
  #--------------------------------------
  printf "${BOLD}Vault Status${RESET}\n"
  echo "─────────────────────────────────────────────────────────────────"
  
  local vault_path="$VAULT_ROOT"
  vault_path="${vault_path/#\~/$HOME}"
  # Convert Windows path to Unix if needed
  if [[ "$vault_path" == *"\\"* ]]; then
    vault_path="${vault_path//\\//}"
  fi

  if [[ -d "$vault_path" ]]; then
    printf "  Vault Directory:    ${GREEN}✓${RESET} exists\n"
    
    local run_dir="$vault_path/Run"
    if [[ -d "$run_dir" ]]; then
      printf "  Run Directory:      ${GREEN}✓${RESET} exists\n"
      
      # Count actual customer dirs
      local actual_dirs=0
      actual_dirs=$(find "$run_dir" -maxdepth 1 -type d -name "CUST-*" 2>/dev/null | wc -l)
      printf "  Customer Dirs:      %d found on disk\n" "$actual_dirs"
    else
      printf "  Run Directory:      ${YELLOW}!${RESET} not found\n"
    fi
  else
    printf "  Vault Directory:    ${RED}✗${RESET} not found\n"
  fi
  echo ""

  #--------------------------------------
  # Customers
  #--------------------------------------
  printf "${BOLD}Customers (${#CUSTOMER_IDS[@]} configured)${RESET}\n"
  echo "─────────────────────────────────────────────────────────────────"
  
  if [[ ${#CUSTOMER_IDS[@]} -eq 0 ]]; then
    printf "  ${YELLOW}No customers configured${RESET}\n"
  else
    local existing=0
    local missing=0
    local complete=0
    
    for id in "${CUSTOMER_IDS[@]}"; do
      local cust_code
      cust_code="$(get_cust_code "$id")"
      local cust_dir="$vault_path/Run/$cust_code"
      
      if [[ -d "$cust_dir" ]]; then
        ((existing++)) || true
        
        # Check if all sections exist
        local sections_ok=true
        for section in "${SECTIONS[@]}"; do
          if [[ ! -d "$cust_dir/$cust_code-$section" ]]; then
            sections_ok=false
            break
          fi
        done
        
        if [[ "$sections_ok" == true ]]; then
          ((complete++)) || true
          if [[ "$verbose" == "true" ]]; then
            printf "  ${GREEN}✓${RESET} %s (complete)\n" "$cust_code"
          fi
        else
          if [[ "$verbose" == "true" ]]; then
            printf "  ${YELLOW}!${RESET} %s (missing sections)\n" "$cust_code"
          fi
        fi
      else
        ((missing++)) || true
        if [[ "$verbose" == "true" ]]; then
          printf "  ${RED}✗${RESET} %s (directory not found)\n" "$cust_code"
        fi
      fi
    done
    
    if [[ "$verbose" != "true" ]]; then
      printf "  Complete:           %d / %d\n" "$complete" "${#CUSTOMER_IDS[@]}"
      printf "  Existing:           %d / %d\n" "$existing" "${#CUSTOMER_IDS[@]}"
      printf "  Missing:            %d\n" "$missing"
    fi
  fi
  echo ""

  #--------------------------------------
  # Sections
  #--------------------------------------
  printf "${BOLD}Sections (${#SECTIONS[@]} configured)${RESET}\n"
  echo "─────────────────────────────────────────────────────────────────"
  
  if [[ ${#SECTIONS[@]} -eq 0 ]]; then
    printf "  ${YELLOW}No sections configured${RESET}\n"
  else
    for section in "${SECTIONS[@]}"; do
      if [[ "$verbose" == "true" ]]; then
        local section_count=0
        for id in "${CUSTOMER_IDS[@]}"; do
          local cust_code
          cust_code="$(get_cust_code "$id")"
          local section_dir="$vault_path/Run/$cust_code/$cust_code-$section"
          if [[ -d "$section_dir" ]]; then
            ((section_count++))
          fi
        done
        printf "  - %s (%d/%d customers)\n" "$section" "$section_count" "${#CUSTOMER_IDS[@]}"
      else
        printf "  - %s\n" "$section"
      fi
    done
  fi
  echo ""

  #--------------------------------------
  # Backups
  #--------------------------------------
  printf "${BOLD}Backups${RESET}\n"
  echo "─────────────────────────────────────────────────────────────────"
  
  if [[ -d "$BACKUP_DIR" ]]; then
    local backup_count=0
    backup_count=$(find "$BACKUP_DIR" -maxdepth 1 -name "*.json" -type f 2>/dev/null | wc -l)
    printf "  Backup Directory:   ${GREEN}✓${RESET} %s\n" "$BACKUP_DIR"
    printf "  Backup Count:       %d\n" "$backup_count"
    
    if [[ "$verbose" == "true" ]] && [[ $backup_count -gt 0 ]]; then
      local latest
      latest=$(find "$BACKUP_DIR" -maxdepth 1 -name "*.json" -type f 2>/dev/null | sort -r | head -1)
      if [[ -n "$latest" ]]; then
        printf "  Latest:             %s\n" "$(basename "$latest")"
      fi
    fi
  else
    printf "  Backup Directory:   ${YELLOW}!${RESET} not found\n"
  fi
  echo ""

  #--------------------------------------
  # Dependencies
  #--------------------------------------
  printf "${BOLD}Dependencies${RESET}\n"
  echo "─────────────────────────────────────────────────────────────────"
  
  local deps_ok=true
  
  for cmd in jq python3; do
    if command -v "$cmd" >/dev/null 2>&1; then
      local version
      case "$cmd" in
        jq) version=$(jq --version 2>/dev/null || echo "unknown") ;;
        python3) version=$(python3 --version 2>/dev/null || echo "unknown") ;;
        *) version="installed" ;;
      esac
      printf "  ${GREEN}✓${RESET} %-15s %s\n" "$cmd" "$version"
    else
      printf "  ${RED}✗${RESET} %-15s not found\n" "$cmd"
      deps_ok=false
    fi
  done
  echo ""

  #--------------------------------------
  # Summary
  #--------------------------------------
  echo "═══════════════════════════════════════════════════════════════"
  
  if [[ "$deps_ok" != true ]]; then
    printf "${YELLOW}⚠ Some dependencies are missing. Run 'install-requirements.sh'${RESET}\n"
  elif [[ ! -f "$CONFIG_JSON" ]]; then
    printf "${YELLOW}⚠ Configuration file not found. Run 'cust-run-config.sh init'${RESET}\n"
  elif [[ ! -d "$vault_path" ]]; then
    printf "${YELLOW}⚠ Vault directory not found. Check VaultRoot setting.${RESET}\n"
  else
    printf "${GREEN}✓ AutoVault is configured and ready${RESET}\n"
  fi
  echo ""
}

#--------------------------------------
# MAIN ENTRY POINT
#--------------------------------------
main() {
  # Parse arguments
  for arg in "$@"; do
    case "$arg" in
      -v|--verbose) VERBOSE=true ;;
    esac
  done

  # Load config
  load_config

  # Show status
  show_status
}

# Only run main if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
