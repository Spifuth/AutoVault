#!/usr/bin/env bash
#===============================================================================
#
#  AUTOVAULT LIBRARY - help.sh
#
#===============================================================================
#
#  DESCRIPTION:    Help system for AutoVault CLI.
#                  Provides formatted help pages for all commands
#                  with color support and examples.
#
#  FUNCTIONS:      usage()        - Main help dispatcher
#                  help_main()    - Main help page (--help)
#                  help_structure - Help for structure command
#                  help_templates - Help for templates command
#                  help_customer  - Help for customer command
#                  help_section   - Help for section command
#                  help_backup    - Help for backup command
#                  help_vault     - Help for vault command
#                  help_config    - Help for config command
#
#  USAGE:          source "$LIB_DIR/help.sh"
#                  usage              # Show main help
#                  usage "templates"  # Show templates help
#
#  COLORS:         Respects NO_COLOR environment variable
#                  Uses ANSI colors for headers and highlights
#
#===============================================================================

# Prevent multiple sourcing
[[ -n "${_HELP_SH_LOADED:-}" ]] && return 0
_HELP_SH_LOADED=1

#--------------------------------------
# HELP COLORS (respects NO_COLOR)
#--------------------------------------
_h_bold()   { if [[ -z "${NO_COLOR:-}" ]]; then echo -ne "\033[1m";  fi; }
_h_dim()    { if [[ -z "${NO_COLOR:-}" ]]; then echo -ne "\033[2m";  fi; }
_h_cyan()   { if [[ -z "${NO_COLOR:-}" ]]; then echo -ne "\033[36m"; fi; }
_h_green()  { if [[ -z "${NO_COLOR:-}" ]]; then echo -ne "\033[32m"; fi; }
_h_yellow() { if [[ -z "${NO_COLOR:-}" ]]; then echo -ne "\033[33m"; fi; }
_h_blue()   { if [[ -z "${NO_COLOR:-}" ]]; then echo -ne "\033[34m"; fi; }
_h_reset()  { if [[ -z "${NO_COLOR:-}" ]]; then echo -ne "\033[0m";  fi; }

#--------------------------------------
# VERSION
#--------------------------------------
AUTOVAULT_VERSION="2.1.0"

#--------------------------------------
# USAGE DISPATCHER
#--------------------------------------
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
    hooks)      help_hooks ;;
    remote)     help_remote ;;
    *)          help_main ;;
  esac
}

#--------------------------------------
# MAIN HELP
#--------------------------------------
help_main() {
  local script_name
  script_name="$(basename "${BASH_SOURCE[2]:-$0}")"
  
  cat <<EOF
$(_h_cyan)┌──────────────────────────────────────────────────────────────┐
│$(_h_reset)                                                              $(_h_cyan)│
│$(_h_reset)    $(_h_bold)█▀█ █ █ ▀█▀ █▀█ █ █ █▀█ █ █ █   ▀█▀$(_h_reset)                    $(_h_cyan)│
│$(_h_reset)    $(_h_bold)█▀█ █▄█  █  █ █ ▀▄▀ █▀█ █▄█ █▄▄  █$(_h_reset)                     $(_h_cyan)│
│$(_h_reset)                                                              $(_h_cyan)│
│$(_h_reset)    $(_h_dim)Obsidian Vault Structure Manager$(_h_reset)                $(_h_cyan)v${AUTOVAULT_VERSION}$(_h_reset)   $(_h_cyan)│
│$(_h_reset)                                                              $(_h_cyan)│
└──────────────────────────────────────────────────────────────┘$(_h_reset)

$(_h_bold)USAGE$(_h_reset)
    $script_name [OPTIONS] COMMAND [ARGS]
    $script_name COMMAND --help

$(_h_bold)OPTIONS$(_h_reset)
    $(_h_green)-v, --verbose$(_h_reset)     Enable verbose/debug output
    $(_h_green)-q, --quiet$(_h_reset)       Only show errors
    $(_h_green)--silent$(_h_reset)          Suppress all output
    $(_h_green)--no-color$(_h_reset)        Disable colored output
    $(_h_green)--dry-run$(_h_reset)         Preview changes without applying
    $(_h_green)--diff$(_h_reset)            Show what would change (diff mode)
    $(_h_green)--version$(_h_reset)         Show version and check for updates
    $(_h_green)-h, --help$(_h_reset)        Show this help message

$(_h_bold)COMMANDS$(_h_reset)
    $(_h_yellow)Configuration$(_h_reset)
    config              Interactive configuration wizard
    validate            Validate configuration file
    status              Show current status
    diff                Show diff of expected vs actual state

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
    remote              Remote vault sync via SSH (push/pull)

    $(_h_yellow)System$(_h_reset)
    requirements        Check/install dependencies
    hooks               Manage automation hooks (list/init/test)

$(_h_bold)QUICK START$(_h_reset)
    $(_h_dim)# First time setup$(_h_reset)
    $script_name config               $(_h_dim)# Configure vault path$(_h_reset)
    $script_name vault init           $(_h_dim)# Create everything$(_h_reset)

    $(_h_dim)# Daily usage$(_h_reset)
    $script_name customer add 31      $(_h_dim)# Add new customer$(_h_reset)
    $script_name templates apply      $(_h_dim)# Apply templates$(_h_reset)
    $script_name status               $(_h_dim)# Check status$(_h_reset)

$(_h_bold)MORE HELP$(_h_reset)
    $script_name templates --help     $(_h_dim)# Help for templates command$(_h_reset)
    $script_name customer --help      $(_h_dim)# Help for customer command$(_h_reset)

$(_h_dim)Documentation: https://github.com/Spifuth/AutoVault/tree/main/docs$(_h_reset)
EOF
}

#--------------------------------------
# CONFIG HELP
#--------------------------------------
help_config() {
  local script_name
  script_name="$(basename "${BASH_SOURCE[2]:-$0}")"
  
  cat <<EOF
$(_h_bold)AUTOVAULT - CONFIG$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $script_name config
    $script_name validate
    $script_name status

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
    Override: CONFIG_JSON=/path/to/config.json $script_name ...

$(_h_bold)EXAMPLES$(_h_reset)
    $script_name config               $(_h_dim)# Interactive setup$(_h_reset)
    $script_name validate             $(_h_dim)# Check config is valid$(_h_reset)
    $script_name -v status            $(_h_dim)# Verbose status$(_h_reset)
EOF
}

#--------------------------------------
# STRUCTURE HELP
#--------------------------------------
help_structure() {
  local script_name
  script_name="$(basename "${BASH_SOURCE[2]:-$0}")"
  
  cat <<EOF
$(_h_bold)AUTOVAULT - STRUCTURE$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $script_name structure
    $script_name test
    $script_name cleanup

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
    $script_name structure            $(_h_dim)# Create structure$(_h_reset)
    $script_name --dry-run structure  $(_h_dim)# Preview creation$(_h_reset)
    $script_name test                 $(_h_dim)# Verify structure$(_h_reset)
    $script_name --dry-run cleanup    $(_h_dim)# Preview cleanup$(_h_reset)
EOF
}

#--------------------------------------
# TEMPLATES HELP
#--------------------------------------
help_templates() {
  local script_name
  script_name="$(basename "${BASH_SOURCE[2]:-$0}")"
  
  cat <<EOF
$(_h_bold)AUTOVAULT - TEMPLATES$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $script_name templates [SUBCOMMAND]

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
    $script_name templates            $(_h_dim)# Apply templates (default)$(_h_reset)
    $script_name templates apply      $(_h_dim)# Same as above$(_h_reset)
    $script_name templates sync       $(_h_dim)# JSON → vault templates$(_h_reset)
    $script_name templates export     $(_h_dim)# vault templates → JSON$(_h_reset)
EOF
}

#--------------------------------------
# CUSTOMER HELP
#--------------------------------------
help_customer() {
  local script_name
  script_name="$(basename "${BASH_SOURCE[2]:-$0}")"
  
  cat <<EOF
$(_h_bold)AUTOVAULT - CUSTOMER$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $script_name customer [SUBCOMMAND] [ID]

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
    $script_name customer             $(_h_dim)# List customers$(_h_reset)
    $script_name customer list        $(_h_dim)# Same as above$(_h_reset)
    $script_name customer add 31      $(_h_dim)# Add customer 31$(_h_reset)
    $script_name customer remove 5    $(_h_dim)# Remove customer 5$(_h_reset)
EOF
}

#--------------------------------------
# SECTION HELP
#--------------------------------------
help_section() {
  local script_name
  script_name="$(basename "${BASH_SOURCE[2]:-$0}")"
  
  cat <<EOF
$(_h_bold)AUTOVAULT - SECTION$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $script_name section [SUBCOMMAND] [NAME]

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
    $script_name section              $(_h_dim)# List sections$(_h_reset)
    $script_name section add URGENT   $(_h_dim)# Add URGENT section$(_h_reset)
    $script_name section remove DIVERS $(_h_dim)# Remove DIVERS$(_h_reset)
EOF
}

#--------------------------------------
# BACKUP HELP
#--------------------------------------
help_backup() {
  local script_name
  script_name="$(basename "${BASH_SOURCE[2]:-$0}")"
  
  cat <<EOF
$(_h_bold)AUTOVAULT - BACKUP$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $script_name backup [SUBCOMMAND] [ARGS]

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
    $script_name backup               $(_h_dim)# List backups$(_h_reset)
    $script_name backup create "Pre-upgrade" $(_h_dim)# Create backup$(_h_reset)
    $script_name backup restore 1     $(_h_dim)# Restore backup #1$(_h_reset)
    $script_name backup cleanup 3     $(_h_dim)# Keep only 3 backups$(_h_reset)
EOF
}

#--------------------------------------
# VAULT HELP
#--------------------------------------
help_vault() {
  local script_name
  script_name="$(basename "${BASH_SOURCE[2]:-$0}")"
  
  cat <<EOF
$(_h_bold)AUTOVAULT - VAULT$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $script_name vault [SUBCOMMAND]

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
    $script_name vault                $(_h_dim)# Full init (default)$(_h_reset)
    $script_name vault init           $(_h_dim)# Same as above$(_h_reset)
    $script_name vault check          $(_h_dim)# Check plugins installed$(_h_reset)
    $script_name vault plugins        $(_h_dim)# Configure plugins only$(_h_reset)
    $script_name vault hub            $(_h_dim)# Regenerate Run-Hub$(_h_reset)
EOF
}

#--------------------------------------
# HOOKS HELP
#--------------------------------------
help_hooks() {
  local script_name
  script_name="$(basename "${BASH_SOURCE[2]:-$0}")"
  
  cat <<EOF
$(_h_bold)AUTOVAULT - HOOKS$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $script_name hooks [SUBCOMMAND]

$(_h_bold)DESCRIPTION$(_h_reset)
    Automation hooks allow custom scripts to run before/after operations.
    Use hooks for notifications, backups, external API calls, etc.

$(_h_bold)SUBCOMMANDS$(_h_reset)
    $(_h_green)list$(_h_reset) $(_h_dim)(default)$(_h_reset)
        List available hooks and show which are installed.

    $(_h_green)init$(_h_reset) [path]
        Create hooks directory with example scripts.
        Default path: ./hooks/

    $(_h_green)test$(_h_reset) <hook-name> [args...]
        Test a specific hook with optional arguments.

$(_h_bold)AVAILABLE HOOKS$(_h_reset)
    $(_h_cyan)pre-customer-remove$(_h_reset)
        Runs BEFORE a customer is removed.
        $(_h_yellow)Can cancel the operation$(_h_reset) by returning non-zero.

    $(_h_cyan)post-customer-remove$(_h_reset)
        Runs AFTER a customer is removed successfully.
        Exit code is logged but doesn't affect operation.

    $(_h_cyan)post-templates-apply$(_h_reset)
        Runs AFTER templates are applied to the vault.
        Receives count of files updated as argument.

    $(_h_cyan)on-error$(_h_reset)
        Runs when ANY error occurs in AutoVault.
        Receives: operation, error message, exit code.

$(_h_bold)HOOK INTERFACE$(_h_reset)
    Hooks receive context as arguments and environment variables:
    
    $(_h_yellow)Arguments:$(_h_reset)     \$1, \$2, etc. - Context specific to each hook
    $(_h_yellow)Environment:$(_h_reset)   VAULT_ROOT, CONFIG_JSON, AUTOVAULT_HOOK

$(_h_bold)CREATING A HOOK$(_h_reset)
    1. $script_name hooks init
    2. cp hooks/pre-customer-remove.sh.example hooks/pre-customer-remove.sh
    3. chmod +x hooks/pre-customer-remove.sh
    4. Edit the script with your custom logic

$(_h_bold)ENVIRONMENT$(_h_reset)
    AUTOVAULT_HOOKS_DIR       Custom hooks directory path
    AUTOVAULT_HOOKS_ENABLED   Set to "false" to disable hooks

$(_h_bold)EXAMPLES$(_h_reset)
    $script_name hooks                  $(_h_dim)# List hooks$(_h_reset)
    $script_name hooks init             $(_h_dim)# Create hooks directory$(_h_reset)
    $script_name hooks test on-error    $(_h_dim)# Test on-error hook$(_h_reset)
EOF
}

#--------------------------------------
# REMOTE HELP
#--------------------------------------
help_remote() {
  local script_name
  script_name="$(basename "${BASH_SOURCE[2]:-$0}")"
  
  cat <<EOF
$(_h_bold)AUTOVAULT - REMOTE$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $script_name remote [SUBCOMMAND] [ARGS]

$(_h_bold)DESCRIPTION$(_h_reset)
    Synchronize your Obsidian vault with remote servers via SSH/rsync.
    Supports multiple remotes with individual configuration.

$(_h_bold)SUBCOMMANDS$(_h_reset)
    $(_h_green)list$(_h_reset) $(_h_dim)(default)$(_h_reset)
        List all configured remotes with connection status.

    $(_h_green)init$(_h_reset)
        Create remotes configuration file (config/remotes.json).

    $(_h_green)add$(_h_reset) <name> <user@host> <path> [port]
        Add a new remote configuration.

    $(_h_green)remove$(_h_reset) <name>
        Remove a remote configuration.

    $(_h_green)test$(_h_reset) <name>
        Test SSH connection and rsync availability.

    $(_h_green)push$(_h_reset) <name>
        Push local vault to remote (upload).

    $(_h_green)pull$(_h_reset) <name>
        Pull remote vault to local (download).

    $(_h_green)status$(_h_reset) <name>
        Compare local and remote vault stats.

$(_h_bold)REQUIREMENTS$(_h_reset)
    - SSH key-based authentication (recommended)
    - rsync installed locally and on remote
    - Remote server accessible via SSH

$(_h_bold)CONFIGURATION$(_h_reset)
    Remotes are stored in: config/remotes.json
    
    Default excludes (not synced):
    - .obsidian/workspace.json
    - .obsidian/workspace-mobile.json
    - .trash/

$(_h_bold)EXAMPLES$(_h_reset)
    $(_h_dim)# Setup a remote$(_h_reset)
    $script_name remote add server me@myserver.com /home/me/vault
    $script_name remote test server
    
    $(_h_dim)# Sync operations$(_h_reset)
    $script_name remote push server         $(_h_dim)# Upload to remote$(_h_reset)
    $script_name remote pull server         $(_h_dim)# Download from remote$(_h_reset)
    $script_name --dry-run remote push srv  $(_h_dim)# Preview changes$(_h_reset)
    
    $(_h_dim)# With custom SSH port$(_h_reset)
    $script_name remote add vps user@vps.example.com /vault 2222
EOF
}
