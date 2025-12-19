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
# USAGE / HELP
#--------------------------------------

# Help colors (respects NO_COLOR)
_h_bold() { [[ -z "${NO_COLOR:-}" ]] && echo -ne "\033[1m" || true; }
_h_dim() { [[ -z "${NO_COLOR:-}" ]] && echo -ne "\033[2m" || true; }
_h_cyan() { [[ -z "${NO_COLOR:-}" ]] && echo -ne "\033[36m" || true; }
_h_green() { [[ -z "${NO_COLOR:-}" ]] && echo -ne "\033[32m" || true; }
_h_yellow() { [[ -z "${NO_COLOR:-}" ]] && echo -ne "\033[33m" || true; }
_h_blue() { [[ -z "${NO_COLOR:-}" ]] && echo -ne "\033[34m" || true; }
_h_reset() { [[ -z "${NO_COLOR:-}" ]] && echo -ne "\033[0m" || true; }

usage() {
  local cmd="${1:-}"
  
  case "$cmd" in
    config)     help_config ;;
    structure)  help_structure ;;
    templates)  help_templates ;;
    customer)   help_customer ;;
    section)    help_section ;;
    backup)     help_backup ;;
    vault)      help_vault ;;
    *)          help_main ;;
  esac
}

help_main() {
  cat <<EOF
$(_h_cyan)┌──────────────────────────────────────────────────────────────┐
│$(_h_reset)                                                              $(_h_cyan)│
│$(_h_reset)    $(_h_bold)█▀█ █ █ ▀█▀ █▀█ █ █ █▀█ █ █ █   ▀█▀$(_h_reset)                    $(_h_cyan)│
│$(_h_reset)    $(_h_bold)█▀█ █▄█  █  █ █ ▀▄▀ █▀█ █▄█ █▄▄  █$(_h_reset)                     $(_h_cyan)│
│$(_h_reset)                                                              $(_h_cyan)│
│$(_h_reset)    $(_h_dim)Obsidian Vault Structure Manager$(_h_reset)                $(_h_cyan)v2.0$(_h_reset)   $(_h_cyan)│
│$(_h_reset)                                                              $(_h_cyan)│
└──────────────────────────────────────────────────────────────┘$(_h_reset)

$(_h_bold)USAGE$(_h_reset)
    $(basename "$0") [OPTIONS] COMMAND [ARGS]
    $(basename "$0") COMMAND --help

$(_h_bold)OPTIONS$(_h_reset)
    $(_h_green)-v, --verbose$(_h_reset)     Enable verbose/debug output
    $(_h_green)-q, --quiet$(_h_reset)       Only show errors
    $(_h_green)--silent$(_h_reset)          Suppress all output
    $(_h_green)--no-color$(_h_reset)        Disable colored output
    $(_h_green)--dry-run$(_h_reset)         Preview changes without applying
    $(_h_green)-h, --help$(_h_reset)        Show this help message

$(_h_bold)COMMANDS$(_h_reset)
    $(_h_yellow)Configuration$(_h_reset)
    config              Interactive configuration wizard
    validate            Validate configuration file
    status              Show current status

    $(_h_yellow)Structure$(_h_reset)
    structure           Create folder structure in vault
    templates           Manage templates (sync/apply/export)
    test                Verify vault structure
    cleanup             Remove vault structure $(_h_dim)(dangerous!)$(_h_reset)

    $(_h_yellow)Management$(_h_reset)
    customer            Manage customers (add/remove/list)
    section             Manage sections (add/remove/list)
    backup              Manage backups (list/restore/create)

    $(_h_yellow)Vault$(_h_reset)
    vault               Obsidian setup (init/plugins/check/hub)

    $(_h_yellow)System$(_h_reset)
    requirements        Check/install dependencies

$(_h_bold)QUICK START$(_h_reset)
    $(_h_dim)# First time setup$(_h_reset)
    $(basename "$0") config               $(_h_dim)# Configure vault path$(_h_reset)
    $(basename "$0") vault init           $(_h_dim)# Create everything$(_h_reset)

    $(_h_dim)# Daily usage$(_h_reset)
    $(basename "$0") customer add 31      $(_h_dim)# Add new customer$(_h_reset)
    $(basename "$0") templates apply      $(_h_dim)# Apply templates$(_h_reset)
    $(basename "$0") status               $(_h_dim)# Check status$(_h_reset)

$(_h_bold)MORE HELP$(_h_reset)
    $(basename "$0") templates --help     $(_h_dim)# Help for templates command$(_h_reset)
    $(basename "$0") customer --help      $(_h_dim)# Help for customer command$(_h_reset)
    man autovault                         $(_h_dim)# Full manual (if installed)$(_h_reset)

$(_h_dim)Documentation: https://github.com/Spifuth/AutoVault/tree/main/docs$(_h_reset)
EOF
}

help_config() {
  cat <<EOF
$(_h_bold)AUTOVAULT - CONFIG$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $(basename "$0") config
    $(basename "$0") validate
    $(basename "$0") status

$(_h_bold)DESCRIPTION$(_h_reset)
    Manage AutoVault configuration settings.

$(_h_bold)COMMANDS$(_h_reset)
    $(_h_green)config$(_h_reset), $(_h_green)init$(_h_reset)
        Launch interactive configuration wizard.
        Prompts for vault path, customer IDs, sections, etc.

    $(_h_green)validate$(_h_reset)
        Validate the configuration file syntax and values.
        Checks JSON format and required fields.

    $(_h_green)status$(_h_reset)
        Display current configuration and vault status.
        Shows customer count, sections, and structure health.

$(_h_bold)CONFIG FILE$(_h_reset)
    Default: config/cust-run-config.json
    Override: CONFIG_JSON=/path/to/config.json $(basename "$0") ...

$(_h_bold)EXAMPLES$(_h_reset)
    $(basename "$0") config               $(_h_dim)# Interactive setup$(_h_reset)
    $(basename "$0") validate             $(_h_dim)# Check config is valid$(_h_reset)
    $(basename "$0") -v status            $(_h_dim)# Verbose status$(_h_reset)
EOF
}

help_structure() {
  cat <<EOF
$(_h_bold)AUTOVAULT - STRUCTURE$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $(basename "$0") structure
    $(basename "$0") test
    $(basename "$0") cleanup

$(_h_bold)DESCRIPTION$(_h_reset)
    Create and manage the vault folder structure.

$(_h_bold)COMMANDS$(_h_reset)
    $(_h_green)structure$(_h_reset), $(_h_green)new$(_h_reset)
        Create the folder structure in the vault:
        - Run/ directory with CUST-XXX folders
        - Section subfolders (FP, RAISED, etc.)
        - Index files for each folder
        - Run-Hub.md master index

    $(_h_green)test$(_h_reset), $(_h_green)verify$(_h_reset)
        Verify the vault structure is correct.
        Reports missing folders or files.

    $(_h_green)cleanup$(_h_reset)
        $(_h_yellow)⚠ DANGEROUS$(_h_reset) - Remove the entire vault structure.
        Requires EnableCleanup=true in config.
        Use --dry-run to preview.

$(_h_bold)STRUCTURE CREATED$(_h_reset)
    <VaultRoot>/
    ├── Run/
    │   ├── CUST-001/
    │   │   ├── CUST-001-Index.md
    │   │   ├── CUST-001-FP/
    │   │   │   └── CUST-001-FP-Index.md
    │   │   └── CUST-001-RAISED/
    │   │       └── CUST-001-RAISED-Index.md
    │   └── ...
    └── Run-Hub.md

$(_h_bold)EXAMPLES$(_h_reset)
    $(basename "$0") structure            $(_h_dim)# Create structure$(_h_reset)
    $(basename "$0") --dry-run structure  $(_h_dim)# Preview creation$(_h_reset)
    $(basename "$0") test                 $(_h_dim)# Verify structure$(_h_reset)
    $(basename "$0") --dry-run cleanup    $(_h_dim)# Preview cleanup$(_h_reset)
EOF
}

help_templates() {
  cat <<EOF
$(_h_bold)AUTOVAULT - TEMPLATES$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $(basename "$0") templates [SUBCOMMAND]

$(_h_bold)DESCRIPTION$(_h_reset)
    Manage Obsidian templates for index files.
    Templates use Templater syntax for dynamic content.

$(_h_bold)SUBCOMMANDS$(_h_reset)
    $(_h_green)apply$(_h_reset) $(_h_dim)(default)$(_h_reset)
        Apply templates to all CUST folder index files.
        Replaces {{CUST_CODE}} and {{SECTION}} placeholders.

    $(_h_green)sync$(_h_reset)
        Sync templates from JSON to vault/_templates/Run/.
        Creates template files from config/templates.json.

    $(_h_green)export$(_h_reset)
        Export templates from vault to JSON.
        Reads vault/_templates/Run/*.md to config/templates.json.

$(_h_bold)TEMPLATE FILES$(_h_reset)
    $(_h_dim)Index templates:$(_h_reset)
    - CUST-Root-Index.md      $(_h_dim)# Main customer index$(_h_reset)
    - CUST-Section-*-Index.md $(_h_dim)# Section indexes$(_h_reset)

    $(_h_dim)Note templates:$(_h_reset)
    - Note-*.md               $(_h_dim)# Templates for new notes$(_h_reset)

$(_h_bold)PLACEHOLDERS$(_h_reset)
    {{CUST_CODE}}   → CUST-001, CUST-002, etc.
    {{SECTION}}     → FP, RAISED, etc.
    <% tp.* %>      → Templater syntax

$(_h_bold)EXAMPLES$(_h_reset)
    $(basename "$0") templates            $(_h_dim)# Apply templates (default)$(_h_reset)
    $(basename "$0") templates apply      $(_h_dim)# Same as above$(_h_reset)
    $(basename "$0") templates sync       $(_h_dim)# JSON → vault templates$(_h_reset)
    $(basename "$0") templates export     $(_h_dim)# vault templates → JSON$(_h_reset)
EOF
}

help_customer() {
  cat <<EOF
$(_h_bold)AUTOVAULT - CUSTOMER$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $(basename "$0") customer [SUBCOMMAND] [ID]

$(_h_bold)DESCRIPTION$(_h_reset)
    Manage customer entries in the vault.

$(_h_bold)SUBCOMMANDS$(_h_reset)
    $(_h_green)list$(_h_reset) $(_h_dim)(default)$(_h_reset)
        List all configured customers.
        Shows ID, code (CUST-XXX), and folder status.

    $(_h_green)add$(_h_reset) <ID>
        Add a new customer with the given ID.
        Creates folder structure and updates config.

    $(_h_green)remove$(_h_reset) <ID>
        Remove a customer by ID.
        Moves folder to backups/ before deletion.

$(_h_bold)ID FORMAT$(_h_reset)
    Customer IDs are integers (e.g., 1, 15, 100).
    They are formatted as CUST-XXX based on CustomerIdWidth.
    With width=3: 1 → CUST-001, 15 → CUST-015

$(_h_bold)EXAMPLES$(_h_reset)
    $(basename "$0") customer             $(_h_dim)# List customers$(_h_reset)
    $(basename "$0") customer list        $(_h_dim)# Same as above$(_h_reset)
    $(basename "$0") customer add 31      $(_h_dim)# Add customer 31$(_h_reset)
    $(basename "$0") customer remove 5    $(_h_dim)# Remove customer 5$(_h_reset)
EOF
}

help_section() {
  cat <<EOF
$(_h_bold)AUTOVAULT - SECTION$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $(basename "$0") section [SUBCOMMAND] [NAME]

$(_h_bold)DESCRIPTION$(_h_reset)
    Manage sections (subfolders in each customer folder).

$(_h_bold)SUBCOMMANDS$(_h_reset)
    $(_h_green)list$(_h_reset) $(_h_dim)(default)$(_h_reset)
        List all configured sections.

    $(_h_green)add$(_h_reset) <NAME>
        Add a new section to all customers.
        Creates folders and index files.

    $(_h_green)remove$(_h_reset) <NAME>
        Remove a section from all customers.
        Moves content to backups/.

$(_h_bold)DEFAULT SECTIONS$(_h_reset)
    FP            $(_h_dim)# False Positives$(_h_reset)
    RAISED        $(_h_dim)# Escalated items$(_h_reset)
    INFORMATIONS  $(_h_dim)# General info$(_h_reset)
    DIVERS        $(_h_dim)# Miscellaneous$(_h_reset)

$(_h_bold)EXAMPLES$(_h_reset)
    $(basename "$0") section              $(_h_dim)# List sections$(_h_reset)
    $(basename "$0") section add URGENT   $(_h_dim)# Add URGENT section$(_h_reset)
    $(basename "$0") section remove DIVERS $(_h_dim)# Remove DIVERS$(_h_reset)
EOF
}

help_backup() {
  cat <<EOF
$(_h_bold)AUTOVAULT - BACKUP$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $(basename "$0") backup [SUBCOMMAND] [ARGS]

$(_h_bold)DESCRIPTION$(_h_reset)
    Manage backups of vault structure and configuration.

$(_h_bold)SUBCOMMANDS$(_h_reset)
    $(_h_green)list$(_h_reset) $(_h_dim)(default)$(_h_reset)
        List all available backups.
        Shows date, size, and description.

    $(_h_green)create$(_h_reset) [DESCRIPTION]
        Create a manual backup with optional description.

    $(_h_green)restore$(_h_reset) <NUMBER>
        Restore a backup by its number (from list).

    $(_h_green)cleanup$(_h_reset) [N]
        Remove old backups, keep N most recent (default: 5).

$(_h_bold)BACKUP LOCATION$(_h_reset)
    Backups are stored in: backups/
    Format: backup-YYYYMMDD-HHMMSS.tar.gz

$(_h_bold)EXAMPLES$(_h_reset)
    $(basename "$0") backup               $(_h_dim)# List backups$(_h_reset)
    $(basename "$0") backup create "Pre-upgrade" $(_h_dim)# Create backup$(_h_reset)
    $(basename "$0") backup restore 1     $(_h_dim)# Restore backup #1$(_h_reset)
    $(basename "$0") backup cleanup 3     $(_h_dim)# Keep only 3 backups$(_h_reset)
EOF
}

help_vault() {
  cat <<EOF
$(_h_bold)AUTOVAULT - VAULT$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $(basename "$0") vault [SUBCOMMAND]

$(_h_bold)DESCRIPTION$(_h_reset)
    Obsidian vault setup and plugin configuration.

$(_h_bold)SUBCOMMANDS$(_h_reset)
    $(_h_green)init$(_h_reset) $(_h_dim)(default)$(_h_reset)
        Full vault initialization:
        1. Create folder structure
        2. Sync templates
        3. Apply templates
        4. Configure plugins
        5. Generate Run-Hub

    $(_h_green)plugins$(_h_reset)
        Configure Obsidian plugin settings.
        Sets up Templater folder_templates, Dataview, etc.

    $(_h_green)check$(_h_reset)
        Check if required plugins are installed.
        Verifies: Templater, Dataview

    $(_h_green)hub$(_h_reset)
        Regenerate Run-Hub.md with Dataview queries.
        Creates dynamic customer/section lists.

$(_h_bold)REQUIRED PLUGINS$(_h_reset)
    - $(_h_cyan)Templater$(_h_reset)    $(_h_dim)# For template placeholders$(_h_reset)
    - $(_h_cyan)Dataview$(_h_reset)     $(_h_dim)# For dynamic queries in Run-Hub$(_h_reset)

$(_h_bold)EXAMPLES$(_h_reset)
    $(basename "$0") vault                $(_h_dim)# Full init (default)$(_h_reset)
    $(basename "$0") vault init           $(_h_dim)# Same as above$(_h_reset)
    $(basename "$0") vault check          $(_h_dim)# Check plugins installed$(_h_reset)
    $(basename "$0") vault plugins        $(_h_dim)# Configure plugins only$(_h_reset)
    $(basename "$0") vault hub            $(_h_dim)# Regenerate Run-Hub$(_h_reset)
EOF
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
