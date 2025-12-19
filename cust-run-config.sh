#!/usr/bin/env bash
#
# cust-run-config.sh - Main CLI orchestrator for AutoVault
#
# This is the entry point for all AutoVault operations.
# It parses CLI arguments and dispatches to the appropriate module.
#
# Usage:
#   cust-run-config.sh [OPTIONS] COMMAND [ARGS]
#
# See --help for full documentation.
#

# Strict mode only when executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
fi

#--------------------------------------
# PATHS
#--------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASH_DIR="$SCRIPT_DIR/bash"
LIB_DIR="$BASH_DIR/lib"
CONFIG_JSON="${CONFIG_JSON:-"$SCRIPT_DIR/config/cust-run-config.json"}"

#--------------------------------------
# SOURCE LIBRARIES
#--------------------------------------
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/config.sh"
source "$LIB_DIR/help.sh"

#--------------------------------------
# GLOBAL FLAGS (can be set via CLI)
#--------------------------------------
DRY_RUN="${DRY_RUN:-false}"
VERBOSE="${VERBOSE:-false}"

#--------------------------------------
# HELPER: RUN BASH SCRIPTS
#--------------------------------------
run_bash() {
  local script_name="$1"
  shift
  local script_path="$BASH_DIR/$script_name"

  if [[ ! -f "$script_path" ]]; then
    log_error "Script not found: $script_path"
    return 1
  fi

  log_debug "Running: $script_path $*"
  
  # Export environment for child scripts
  export_cust_env
  
  bash "$script_path" "$@"
}

#--------------------------------------
# INTERACTIVE CONFIG
#--------------------------------------
interactive_config() {
  # Load existing config first (if any) to show current values
  load_config 2>/dev/null || true
  
  log_info "Interactive configuration mode"
  log_info "Press Enter to keep current/default values"
  echo ""

  # Display current configuration
  echo "Current configuration:"
  echo "  1. VaultRoot:            $VAULT_ROOT"
  echo "  2. CustomerIdWidth:      $CUSTOMER_ID_WIDTH"
  echo "  3. CustomerIds:          ${CUSTOMER_IDS[*]}"
  echo "  4. Sections:             ${SECTIONS[*]}"
  echo "  5. TemplateRelativeRoot: $TEMPLATE_RELATIVE_ROOT"
  echo "  6. EnableCleanup:        $ENABLE_CLEANUP"
  echo ""

  # VaultRoot
  VAULT_ROOT="$(prompt_value "Vault root path" "$VAULT_ROOT")"

  # CustomerIdWidth
  CUSTOMER_ID_WIDTH="$(prompt_value "Customer ID width (padding)" "$CUSTOMER_ID_WIDTH")"

  # CustomerIds
  local new_ids_str
  new_ids_str="$(prompt_list "Customer IDs" "${CUSTOMER_IDS[@]}")"
  read -ra CUSTOMER_IDS <<< "$new_ids_str"

  # Sections
  local new_sections_str
  new_sections_str="$(prompt_list "Sections" "${SECTIONS[@]}")"
  read -ra SECTIONS <<< "$new_sections_str"

  # TemplateRelativeRoot
  TEMPLATE_RELATIVE_ROOT="$(prompt_value "Template relative root" "$TEMPLATE_RELATIVE_ROOT")"

  # EnableCleanup
  local enable_cleanup_input
  enable_cleanup_input="$(prompt_value "Enable cleanup (true/false)" "$ENABLE_CLEANUP")"
  if [[ "$enable_cleanup_input" =~ ^[Tt]rue$ ]]; then
    ENABLE_CLEANUP="true"
  else
    ENABLE_CLEANUP="false"
  fi

  echo ""
  log_info "Configuration summary:"
  echo "  VaultRoot:            $VAULT_ROOT"
  echo "  CustomerIdWidth:      $CUSTOMER_ID_WIDTH"
  echo "  CustomerIds:          ${CUSTOMER_IDS[*]}"
  echo "  Sections:             ${SECTIONS[*]}"
  echo "  TemplateRelativeRoot: $TEMPLATE_RELATIVE_ROOT"
  echo "  EnableCleanup:        $ENABLE_CLEANUP"
  echo ""

  local confirm
  printf "Save this configuration? [y/N]: "
  read -r confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    log_warn "Configuration cancelled"
    return 1
  fi

  # Force write the new config
  if ! ensure_config_json; then
    log_error "Failed to write configuration"
    return 1
  fi

  log_success "Configuration saved to $CONFIG_JSON"
}

#--------------------------------------
# MAIN
#--------------------------------------
main() {
  # Parse global options first
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -v|--verbose)
        LOG_LEVEL=4
        VERBOSE=true
        shift
        ;;
      -q|--quiet)
        LOG_LEVEL=1
        shift
        ;;
      --silent)
        LOG_LEVEL=0
        shift
        ;;
      --no-color)
        NO_COLOR=1
        setup_colors
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        export DRY_RUN
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -*)
        log_error "Unknown option: $1"
        echo ""
        usage
        exit 1
        ;;
      *)
        break
        ;;
    esac
  done

  local cmd="${1:-}"
  shift || true

  if [[ -z "$cmd" ]]; then
    usage
    exit 1
  fi

  # Handle --help for subcommands: "templates --help" or "templates help"
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" || "${1:-}" == "help" ]]; then
    usage "$cmd"
    exit 0
  fi

  log_debug "Command: $cmd"
  log_debug "Log level: $LOG_LEVEL"
  log_debug "Dry run: $DRY_RUN"

  # Handle requirements command before loading config (which requires jq/python3)
  if [[ "$cmd" == "requirements" || "$cmd" == "install" ]]; then
    local subcmd="${1:-check}"
    shift || true
    bash "$BASH_DIR/Install-Requirements.sh" "$subcmd" "$@"
    exit $?
  fi

  # Load configuration
  load_config

  # Dispatch to appropriate handler
  case "$cmd" in
    #--- Configuration ---
    config|setup|init)
      interactive_config
      ;;
    validate)
      bash "$BASH_DIR/Validate-Config.sh" "$@"
      ;;
    status)
      VERBOSE="$VERBOSE" bash "$BASH_DIR/Show-Status.sh" "$@"
      ;;

    #--- Structure Management ---
    structure|new)
      log_info "Using configuration from $CONFIG_JSON"
      run_bash "New-CustRunStructure.sh" "$@"
      ;;
    templates|apply)
      log_info "Using configuration from $CONFIG_JSON"
      local subcmd="${1:-apply}"
      shift || true
      case "$subcmd" in
        export|sync|apply)
          run_bash "Manage-Templates.sh" "$subcmd" "$@"
          ;;
        *)
          # Legacy: if first arg is not a subcommand, treat as "apply"
          run_bash "Manage-Templates.sh" apply "$subcmd" "$@"
          ;;
      esac
      ;;
    test|verify)
      log_info "Using configuration from $CONFIG_JSON"
      run_bash "Test-CustRunStructure.sh" "$@"
      ;;
    cleanup)
      log_warn "Using configuration from $CONFIG_JSON"
      run_bash "Cleanup-CustRunStructure.sh" "$@"
      ;;

    #--- Customer Management ---
    customer|customers)
      local subcmd="${1:-list}"
      shift || true
      VERBOSE="$VERBOSE" bash "$BASH_DIR/Manage-Customers.sh" "$subcmd" "$@"
      ;;
    # Legacy commands (backwards compatibility)
    add-customer|add)
      if [[ "$cmd" == "add" ]] && [[ -z "${1:-}" ]]; then
        # Plain "add" without args - show help
        log_error "Usage: cust-run-config.sh customer add <id>"
        exit 1
      fi
      bash "$BASH_DIR/Manage-Customers.sh" add "$@"
      ;;
    remove-customer|remove)
      if [[ "$cmd" == "remove" ]] && [[ -z "${1:-}" ]]; then
        log_error "Usage: cust-run-config.sh customer remove <id>"
        exit 1
      fi
      bash "$BASH_DIR/Manage-Customers.sh" remove "$@"
      ;;
    list-customers|list)
      VERBOSE="$VERBOSE" bash "$BASH_DIR/Manage-Customers.sh" list
      ;;

    #--- Section Management ---
    section|sections)
      local subcmd="${1:-list}"
      shift || true
      VERBOSE="$VERBOSE" bash "$BASH_DIR/Manage-Sections.sh" "$subcmd" "$@"
      ;;
    # Legacy commands
    add-section)
      bash "$BASH_DIR/Manage-Sections.sh" add "$@"
      ;;
    remove-section)
      bash "$BASH_DIR/Manage-Sections.sh" remove "$@"
      ;;
    list-sections)
      VERBOSE="$VERBOSE" bash "$BASH_DIR/Manage-Sections.sh" list
      ;;

    #--- Backup Management ---
    backup|backups)
      local subcmd="${1:-list}"
      shift || true
      bash "$BASH_DIR/Manage-Backups.sh" "$subcmd" "$@"
      ;;
    # Legacy commands
    list-backups)
      bash "$BASH_DIR/Manage-Backups.sh" list "$@"
      ;;
    restore-backup|restore)
      bash "$BASH_DIR/Manage-Backups.sh" restore "$@"
      ;;

    #--- Vault Management ---
    vault)
      local subcmd="${1:-init}"
      shift || true
      case "$subcmd" in
        init|plugins|check|hub)
          run_bash "Configure-ObsidianPlugins.sh" "$subcmd" "$@"
          ;;
        *)
          log_error "Unknown vault subcommand: $subcmd"
          log_info "Available: init, plugins, check, hub"
          exit 1
          ;;
      esac
      ;;

    #--- Unknown ---
    *)
      log_error "Unknown command: $cmd"
      echo ""
      usage
      exit 1
      ;;
  esac
}

# Run main only when executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
