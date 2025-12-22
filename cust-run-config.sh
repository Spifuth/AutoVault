#!/usr/bin/env bash
#===============================================================================
#
#          ___         __       _    __            ____
#         /   | __  __/ /____  | |  / /___ ___  __/ / /_
#        / /| |/ / / / __/ _ \ | | / / __ `/ / / / / __/
#       / ___ / /_/ / /_/ (_) || |/ / /_/ / /_/ / / /_
#      /_/  |_\__,_/\__/\___/ |___/\__,_/\__,_/_/\__/
#
#===============================================================================
#
#  SCRIPT NAME:    cust-run-config.sh
#  DESCRIPTION:    Main CLI orchestrator for AutoVault
#                  Entry point for all AutoVault operations - parses CLI 
#                  arguments and dispatches to the appropriate module.
#
#  USAGE:          ./cust-run-config.sh [OPTIONS] COMMAND [ARGS]
#                  ./cust-run-config.sh --help
#
#  COMMANDS:       structure   - Create folder structure for customers
#                  templates   - Manage markdown templates (sync/apply/export)
#                  customer    - Add/remove/list customers
#                  section     - Add/remove/list sections
#                  backup      - Backup and restore configuration
#                  validate    - Validate configuration file
#                  status      - Show current configuration status
#                  vault       - Initialize Obsidian vault and plugins
#
#  OPTIONS:        -v, --verbose    Increase output verbosity
#                  -q, --quiet      Suppress non-error output
#                  --dry-run        Show what would be done without executing
#                  --no-color       Disable colored output
#                  -h, --help       Display help information
#
#  DEPENDENCIES:   bash >= 4.0, jq, python3
#
#  AUTHOR:         AutoVault Project
#  CREATED:        2024
#  REPOSITORY:     https://github.com/Spifuth/AutoVault
#
#===============================================================================

# Strict mode only when executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
fi

#--------------------------------------
# PATHS
#--------------------------------------
# Resolve symlinks to get the real script location
_resolve_symlink() {
  local target="$1"
  while [[ -L "$target" ]]; do
    local dir="$(cd "$(dirname "$target")" && pwd)"
    target="$(readlink "$target")"
    [[ "$target" != /* ]] && target="$dir/$target"
  done
  echo "$target"
}

SCRIPT_PATH="$(_resolve_symlink "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
BASH_DIR="$SCRIPT_DIR/bash"
LIB_DIR="$BASH_DIR/lib"
CONFIG_JSON="${CONFIG_JSON:-"$SCRIPT_DIR/config/cust-run-config.json"}"

#--------------------------------------
# SOURCE LIBRARIES
#--------------------------------------
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/config.sh"
source "$LIB_DIR/help.sh"
source "$LIB_DIR/version.sh"
source "$LIB_DIR/diff.sh"
source "$LIB_DIR/hooks.sh"
source "$LIB_DIR/remote.sh"

#--------------------------------------
# GLOBAL FLAGS (can be set via CLI)
#--------------------------------------
DRY_RUN="${DRY_RUN:-false}"
VERBOSE="${VERBOSE:-false}"
DIFF_MODE="${DIFF_MODE:-false}"

#--------------------------------------
# ERROR HANDLER
#--------------------------------------
handle_error() {
  local exit_code=$?
  local line_number="$1"
  local command="${BASH_COMMAND:-unknown}"
  local operation="${CURRENT_OPERATION:-unknown}"
  
  # Don't trigger hook for expected exits
  [[ $exit_code -eq 0 ]] && return 0
  
  # Trigger on-error hook
  trigger_error_hook "Command '$command' failed at line $line_number" "$operation" "$exit_code"
}

# Set up error trap (only when executed directly)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  trap 'handle_error ${LINENO}' ERR
fi

# Track current operation for error hook
CURRENT_OPERATION="init"

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
# INTERACTIVE CONFIG WIZARD
#--------------------------------------
interactive_config() {
  source "$LIB_DIR/logging.sh"
  
  # Banner
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${NC}                                                              ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}    ${BOLD}🔧 AutoVault Configuration Wizard${NC}                        ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}                                                              ${CYAN}║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  
  # Try to load existing config
  local has_existing_config=false
  if [[ -f "$CONFIG_JSON" ]] && load_config 2>/dev/null; then
    has_existing_config=true
    echo -e "${GREEN}✓${NC} Found existing configuration: ${DIM}$CONFIG_JSON${NC}"
    echo ""
  else
    # Set defaults for new config
    VAULT_ROOT="${HOME}/Obsidian/MyVault"
    CUSTOMER_ID_WIDTH=3
    CUSTOMER_IDS=(1 2 3)
    SECTIONS=("FP" "RAISED" "INFORMATIONS" "DIVERS")
    TEMPLATE_RELATIVE_ROOT="_templates/run"
    ENABLE_CLEANUP=false
  fi

  echo -e "${DIM}Press Enter to keep current/default values${NC}"
  echo -e "${DIM}Use Tab for path completion${NC}"
  echo ""

  # Step 1: Vault Root
  echo -e "${YELLOW}━━━ Step 1/6: Vault Location ━━━${NC}"
  echo -e "${DIM}Where is your Obsidian vault located?${NC}"
  VAULT_ROOT="$(prompt_path "Vault root path" "$VAULT_ROOT")"
  
  # Validate vault path
  if [[ ! -d "$VAULT_ROOT" ]]; then
    echo -e "${YELLOW}⚠${NC}  Directory doesn't exist. It will be created."
    local create_vault
    printf "Create it now? [Y/n]: "
    read -r create_vault
    if [[ ! "$create_vault" =~ ^[Nn] ]]; then
      mkdir -p "$VAULT_ROOT"
      echo -e "${GREEN}✓${NC} Created: $VAULT_ROOT"
    fi
  else
    echo -e "${GREEN}✓${NC} Vault found: $VAULT_ROOT"
  fi
  echo ""

  # Step 2: Customer ID Width
  echo -e "${YELLOW}━━━ Step 2/6: Customer ID Format ━━━${NC}"
  echo -e "${DIM}How many digits for customer IDs? (e.g., 3 = CUST-001)${NC}"
  while true; do
    CUSTOMER_ID_WIDTH="$(prompt_value "ID width (1-5)" "$CUSTOMER_ID_WIDTH")"
    if [[ "$CUSTOMER_ID_WIDTH" =~ ^[1-5]$ ]]; then
      echo -e "${GREEN}✓${NC} Format: CUST-$(printf "%0${CUSTOMER_ID_WIDTH}d" 42)"
      break
    else
      echo -e "${RED}✗${NC} Please enter a number between 1 and 5"
    fi
  done
  echo ""

  # Step 3: Customer IDs
  echo -e "${YELLOW}━━━ Step 3/6: Customer IDs ━━━${NC}"
  echo -e "${DIM}Enter customer IDs (numbers separated by spaces)${NC}"
  echo -e "${DIM}Example: 1 2 3 10 42${NC}"
  while true; do
    local ids_str
    ids_str="$(prompt_list "Customer IDs" "${CUSTOMER_IDS[@]}")"
    
    # Validate all are numbers
    local valid=true
    local -a new_ids=()
    for id in $ids_str; do
      if [[ "$id" =~ ^[0-9]+$ ]]; then
        new_ids+=("$id")
      else
        echo -e "${RED}✗${NC} '$id' is not a valid number"
        valid=false
        break
      fi
    done
    
    if [[ "$valid" == "true" ]] && [[ ${#new_ids[@]} -gt 0 ]]; then
      CUSTOMER_IDS=("${new_ids[@]}")
      echo -e "${GREEN}✓${NC} ${#CUSTOMER_IDS[@]} customer(s): ${CUSTOMER_IDS[*]}"
      break
    elif [[ ${#new_ids[@]} -eq 0 ]]; then
      echo -e "${RED}✗${NC} At least one customer ID is required"
    fi
  done
  echo ""

  # Step 4: Sections
  echo -e "${YELLOW}━━━ Step 4/6: Sections ━━━${NC}"
  echo -e "${DIM}Enter section names (separated by spaces)${NC}"
  echo -e "${DIM}Default: FP RAISED INFORMATIONS DIVERS${NC}"
  while true; do
    local sections_str
    sections_str="$(prompt_list "Sections" "${SECTIONS[@]}")"
    
    # Parse sections (uppercase them)
    local -a new_sections=()
    for section in $sections_str; do
      new_sections+=("${section^^}")
    done
    
    if [[ ${#new_sections[@]} -gt 0 ]]; then
      SECTIONS=("${new_sections[@]}")
      echo -e "${GREEN}✓${NC} ${#SECTIONS[@]} section(s): ${SECTIONS[*]}"
      break
    else
      echo -e "${RED}✗${NC} At least one section is required"
    fi
  done
  echo ""

  # Step 5: Template Location
  echo -e "${YELLOW}━━━ Step 5/6: Template Location ━━━${NC}"
  echo -e "${DIM}Where should templates be stored (relative to vault)?${NC}"
  TEMPLATE_RELATIVE_ROOT="$(prompt_value "Template path" "$TEMPLATE_RELATIVE_ROOT")"
  echo -e "${GREEN}✓${NC} Templates: \$VAULT/${TEMPLATE_RELATIVE_ROOT}"
  echo ""

  # Step 6: Cleanup Mode
  echo -e "${YELLOW}━━━ Step 6/6: Cleanup Mode ━━━${NC}"
  echo -e "${DIM}Enable cleanup command? (removes orphan folders)${NC}"
  echo -e "${DIM}${RED}Warning: This can delete data if misconfigured!${NC}"
  local enable_cleanup_input
  while true; do
    printf "Enable cleanup? [y/N]: "
    read -r enable_cleanup_input
    if [[ -z "$enable_cleanup_input" ]] || [[ "$enable_cleanup_input" =~ ^[Nn] ]]; then
      ENABLE_CLEANUP=false
      echo -e "${GREEN}✓${NC} Cleanup: ${YELLOW}disabled${NC} (safe)"
      break
    elif [[ "$enable_cleanup_input" =~ ^[Yy] ]]; then
      ENABLE_CLEANUP=true
      echo -e "${GREEN}✓${NC} Cleanup: ${RED}enabled${NC}"
      break
    fi
  done
  echo ""

  # Summary
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${NC}               ${BOLD}📋 Configuration Summary${NC}                       ${CYAN}║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "  ${BOLD}Vault Root:${NC}        $VAULT_ROOT"
  echo -e "  ${BOLD}ID Format:${NC}         CUST-$(printf "%0${CUSTOMER_ID_WIDTH}d" 1) (width: $CUSTOMER_ID_WIDTH)"
  echo -e "  ${BOLD}Customers:${NC}         ${CUSTOMER_IDS[*]} (${#CUSTOMER_IDS[@]} total)"
  echo -e "  ${BOLD}Sections:${NC}          ${SECTIONS[*]} (${#SECTIONS[@]} total)"
  echo -e "  ${BOLD}Templates:${NC}         ${TEMPLATE_RELATIVE_ROOT}"
  echo -e "  ${BOLD}Cleanup:${NC}           $(if [[ "$ENABLE_CLEANUP" == "true" ]]; then echo -e "${RED}enabled${NC}"; else echo -e "${GREEN}disabled${NC}"; fi)"
  echo ""
  echo -e "  ${DIM}Config file: $CONFIG_JSON${NC}"
  echo ""

  # Confirm save
  local confirm
  printf "${BOLD}Save this configuration? [Y/n]:${NC} "
  read -r confirm
  if [[ "$confirm" =~ ^[Nn] ]]; then
    log_warn "Configuration cancelled"
    return 1
  fi

  # Save config
  if ! ensure_config_json; then
    log_error "Failed to write configuration"
    return 1
  fi

  echo ""
  log_success "Configuration saved to $CONFIG_JSON"
  echo ""
  
  # Next steps
  echo -e "${CYAN}━━━ Next Steps ━━━${NC}"
  echo -e "  1. Create vault structure:  ${DIM}./cust-run-config.sh structure${NC}"
  echo -e "  2. Sync templates:          ${DIM}./cust-run-config.sh templates sync${NC}"
  echo -e "  3. Apply templates:         ${DIM}./cust-run-config.sh templates apply${NC}"
  echo -e "  4. Check status:            ${DIM}./cust-run-config.sh status${NC}"
  echo ""
  echo -e "${DIM}Or run 'vault init' to do all at once:${NC}"
  echo -e "  ${BOLD}./cust-run-config.sh vault init${NC}"
  echo ""
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
        export NO_COLOR=1
        setup_colors
        shift
        ;;
      --dry-run)
        DRY_RUN=true
        export DRY_RUN
        shift
        ;;
      --diff)
        DIFF_MODE=true
        export DIFF_MODE
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --version)
        show_version
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

  # Handle completions command (doesn't need config)
  if [[ "$cmd" == "completions" ]]; then
    local subcmd="${1:-status}"
    shift || true
    DRY_RUN="$DRY_RUN" bash "$BASH_DIR/Install-Completions.sh" "$subcmd" "$@"
    exit $?
  fi

  # Handle alias command (doesn't need config)
  if [[ "$cmd" == "alias" ]]; then
    local subcmd="${1:-status}"
    shift || true
    DRY_RUN="$DRY_RUN" bash "$BASH_DIR/Install-Alias.sh" "$subcmd" "$@"
    exit $?
  fi

  # Load configuration
  load_config

  # Dispatch to appropriate handler
  case "$cmd" in
    #--- Configuration ---
    config|setup)
      interactive_config
      ;;
    validate)
      bash "$BASH_DIR/Validate-Config.sh" "$@"
      ;;
    status)
      VERBOSE="$VERBOSE" bash "$BASH_DIR/Show-Status.sh" "$@"
      ;;
    stats|statistics)
      bash "$BASH_DIR/Show-Statistics.sh" "$@"
      ;;

    #--- Diff Mode ---
    diff)
      local diff_target="${1:-all}"
      run_full_diff "$VAULT_ROOT" "$diff_target"
      ;;

    #--- Structure Management ---
    structure|new)
      log_info "Using configuration from $CONFIG_JSON"
      # If diff mode, show diff and exit
      if [[ "$DIFF_MODE" == "true" ]]; then
        run_full_diff "$VAULT_ROOT" "structure"
        exit 0
      fi
      run_bash "New-CustRunStructure.sh" "$@"
      ;;
    templates|apply)
      log_info "Using configuration from $CONFIG_JSON"
      local subcmd="${1:-apply}"
      shift || true
      # If diff mode for templates apply
      if [[ "$DIFF_MODE" == "true" ]] && [[ "$subcmd" == "apply" ]]; then
        run_full_diff "$VAULT_ROOT" "templates"
        exit 0
      fi
      case "$subcmd" in
        export|sync|apply|preview|list)
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

    #--- Init (New Vault) ---
    init)
      run_bash "Init-Vault.sh" "$@"
      ;;

    #--- Doctor (Diagnostics) ---
    doctor|diagnose|check)
      run_bash "Doctor.sh" "$@"
      ;;

    #--- Search ---
    search|find|grep)
      run_bash "Search-Vault.sh" "$@"
      ;;

    #--- Archive ---
    archive)
      run_bash "Archive-Customer.sh" "$@"
      ;;

    #--- UI Demo ---
    demo)
      run_bash "Show-Demo.sh" "$@"
      ;;

    #--- Theme Configuration ---
    theme)
      run_bash "Configure-Theme.sh" "$@"
      ;;

    #--- Hooks Management ---
    hooks)
      CURRENT_OPERATION="hooks"
      local subcmd="${1:-list}"
      shift || true
      case "$subcmd" in
        --help|-h)
          usage "hooks"
          ;;
        list)
          list_hooks
          ;;
        init)
          init_hooks_dir "${1:-}"
          ;;
        test)
          local hook_name="${1:-}"
          if [[ -z "$hook_name" ]]; then
            log_error "Usage: cust-run-config.sh hooks test <hook-name> [args...]"
            exit 1
          fi
          shift
          log_info "Testing hook: $hook_name"
          if run_hook "$hook_name" "$@"; then
            log_success "Hook test completed successfully"
          else
            log_error "Hook test failed"
            exit 1
          fi
          ;;
        *)
          log_error "Unknown hooks subcommand: $subcmd"
          log_info "Available: list, init, test"
          exit 1
          ;;
      esac
      ;;

    #--- Remote Vault Sync ---
    remote)
      CURRENT_OPERATION="remote"
      local subcmd="${1:-list}"
      shift || true
      case "$subcmd" in
        --help|-h)
          usage "remote"
          ;;
        list)
          list_remotes
          ;;
        init)
          init_remotes_config
          ;;
        add)
          add_remote "$@"
          ;;
        remove|rm)
          remove_remote "$@"
          ;;
        test)
          test_remote "$@"
          ;;
        push)
          remote_push "$@"
          ;;
        pull)
          remote_pull "$@"
          ;;
        status)
          remote_status "$@"
          ;;
        *)
          log_error "Unknown remote subcommand: $subcmd"
          log_info "Available: list, init, add, remove, test, push, pull, status"
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
