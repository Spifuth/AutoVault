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
# USAGE DISPATCHER
#--------------------------------------
usage() {
  local cmd="${1:-}"
  
  case "$cmd" in
    config)       help_config ;;
    structure)    help_structure ;;
    templates)    help_templates ;;
    customer)     help_customer ;;
    section)      help_section ;;
    backup)       help_backup ;;
    vault)        help_vault ;;
    vaults)       help_vaults ;;
    plugins)      help_plugins ;;
    encrypt)      help_encrypt ;;
    hooks)        help_hooks ;;
    completions)  help_completions ;;
    alias)        help_alias ;;
    remote)       help_remote ;;
    init)         help_init ;;
    doctor)       help_doctor ;;
    search)       help_search ;;
    archive)      help_archive ;;
    export)       help_export ;;
    git-sync)     help_git_sync ;;
    theme)        help_theme ;;
    demo)         help_demo ;;
    *)            help_main ;;
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
    archive             Archive a customer (zip + optional remove)

    $(_h_yellow)Vault$(_h_reset)
    init                Initialize new vault from scratch
    vault               Obsidian setup (init/plugins/check/hub)
    remote              Remote vault sync via SSH (push/pull)
    vaults              Multi-vault management (switch/add/list)

    $(_h_yellow)Utilities$(_h_reset)
    doctor              Run diagnostics (config, structure, perms)
    search              Search across all customers/notes
    stats               Show vault statistics

    $(_h_yellow)Advanced$(_h_reset)
    plugins             Manage plugins (list/enable/create)
    encrypt             Encrypt sensitive notes (init/lock/unlock)

    $(_h_yellow)System$(_h_reset)
    requirements        Check/install dependencies
    completions         Install shell completions (bash/zsh)
    alias               Create system alias (autovault, av, etc.)
    hooks               Manage automation hooks (list/init/test)
    theme               Configure color theme (dark/light/auto)
    demo                UI components demo (progress/spinner/etc.)

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
# COMPLETIONS HELP
#--------------------------------------
help_completions() {
  local script_name
  script_name="$(basename "${BASH_SOURCE[2]:-$0}")"
  
  cat <<EOF
$(_h_bold)AUTOVAULT - COMPLETIONS$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $script_name completions [SUBCOMMAND] [OPTIONS]

$(_h_bold)DESCRIPTION$(_h_reset)
    Install or manage shell tab-completion scripts for AutoVault.
    Supports Bash and Zsh with automatic shell detection.

$(_h_bold)SUBCOMMANDS$(_h_reset)
    $(_h_green)status$(_h_reset) $(_h_dim)(default)$(_h_reset)
        Show current completion installation status.

    $(_h_green)install$(_h_reset) [shell] [--user|--system]
        Install completions for the specified shell.
        Auto-detects current shell if not specified.

    $(_h_green)uninstall$(_h_reset) [shell]
        Remove installed completion scripts.

$(_h_bold)OPTIONS$(_h_reset)
    --shell=<bash|zsh|all>    Target specific shell
    --user                    Install for current user only (default)
    --system                  Install system-wide (requires sudo)

$(_h_bold)INSTALL LOCATIONS$(_h_reset)
    Bash (user):    ~/.local/share/bash-completion/completions/
    Bash (system):  /etc/bash_completion.d/
    Zsh (user):     ~/.zsh/completions/ or ~/.oh-my-zsh/completions/
    Zsh (system):   /usr/share/zsh/site-functions/

$(_h_bold)EXAMPLES$(_h_reset)
    $script_name completions                $(_h_dim)# Show status$(_h_reset)
    $script_name completions install        $(_h_dim)# Install for current shell$(_h_reset)
    $script_name completions install bash   $(_h_dim)# Install Bash completions$(_h_reset)
    $script_name completions install zsh    $(_h_dim)# Install Zsh completions$(_h_reset)
    $script_name completions install all    $(_h_dim)# Install for all shells$(_h_reset)
    $script_name completions install --system  $(_h_dim)# System-wide install$(_h_reset)
    $script_name completions uninstall      $(_h_dim)# Remove all completions$(_h_reset)
EOF
}

#--------------------------------------
# ALIAS HELP
#--------------------------------------
help_alias() {
  local script_name
  script_name="$(basename "${BASH_SOURCE[2]:-$0}")"
  
  cat <<EOF
$(_h_bold)AUTOVAULT - ALIAS$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $script_name alias [SUBCOMMAND] [OPTIONS]

$(_h_bold)DESCRIPTION$(_h_reset)
    Create a system alias or symlink so you can run AutoVault from
    anywhere with a short command like 'autovault' or 'av'.

$(_h_bold)SUBCOMMANDS$(_h_reset)
    $(_h_green)status$(_h_reset) $(_h_dim)(default)$(_h_reset)
        Show current alias installation status.

    $(_h_green)install$(_h_reset) [name] [--method=<method>] [--system]
        Create an alias with the specified name.
        Default name: autovault

    $(_h_green)uninstall$(_h_reset) [name] [--all]
        Remove installed alias(es).

$(_h_bold)OPTIONS$(_h_reset)
    --name=<alias>      Custom alias name (default: autovault)
    --method=<method>   Installation method:
                          symlink - Symlink in PATH (default, recommended)
                          alias   - Shell alias in rc file
    --user              Install for current user only (default)
    --system            Install system-wide (requires sudo)
    --all               Remove all aliases (with uninstall)

$(_h_bold)INSTALLATION METHODS$(_h_reset)
    $(_h_yellow)symlink$(_h_reset) (recommended)
        Creates a symbolic link in ~/.local/bin or /usr/local/bin.
        Works across all shells, survives shell restarts.

    $(_h_yellow)alias$(_h_reset)
        Adds an alias to your ~/.bashrc or ~/.zshrc.
        Shell-specific, requires sourcing rc file after install.

$(_h_bold)SUGGESTED NAMES$(_h_reset)
    autovault   Full name (default)
    av          Short and quick
    vault       If you don't use Hashicorp Vault
    custrun     Descriptive

$(_h_bold)EXAMPLES$(_h_reset)
    $script_name alias                      $(_h_dim)# Show status$(_h_reset)
    $script_name alias install              $(_h_dim)# Install as 'autovault'$(_h_reset)
    $script_name alias install av           $(_h_dim)# Install as 'av'$(_h_reset)
    $script_name alias install --name=vault $(_h_dim)# Install as 'vault'$(_h_reset)
    $script_name alias install --system     $(_h_dim)# System-wide (/usr/local/bin)$(_h_reset)
    $script_name alias install --method=alias  $(_h_dim)# Shell alias instead$(_h_reset)
    $script_name alias uninstall av         $(_h_dim)# Remove 'av' alias$(_h_reset)
    $script_name alias uninstall --all      $(_h_dim)# Remove all aliases$(_h_reset)
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

#--------------------------------------
# INIT HELP
#--------------------------------------
help_init() {
  local script_name
  script_name="$(basename "${BASH_SOURCE[2]:-$0}")"
  
  cat <<EOF
$(_h_bold)AUTOVAULT - INIT$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $script_name init [OPTIONS]

$(_h_bold)DESCRIPTION$(_h_reset)
    Initialize a new AutoVault from scratch. Creates the vault directory,
    configuration files, templates, and initial folder structure.

    This is the recommended way to start a new AutoVault installation.

$(_h_bold)OPTIONS$(_h_reset)
    $(_h_green)--path <dir>$(_h_reset)
        Vault path (default: ~/Obsidian/CustRunVault)

    $(_h_green)--profile <name>$(_h_reset)
        Use a profile template. Available profiles:
        - $(_h_yellow)minimal$(_h_reset)    Basic structure, few sections
        - $(_h_yellow)pentest$(_h_reset)    Penetration testing workflow
        - $(_h_yellow)audit$(_h_reset)      Security audit workflow
        - $(_h_yellow)bugbounty$(_h_reset)  Bug bounty hunting workflow

    $(_h_green)--force$(_h_reset)
        Overwrite existing configuration

    $(_h_green)--no-structure$(_h_reset)
        Skip creating initial folder structure

$(_h_bold)WHAT IT CREATES$(_h_reset)
    vault/
    ├── _templates/
    │   └── run/
    │       ├── root/          # Customer-level templates
    │       └── section/       # Section-level templates
    ├── _archive/              # For archived customers
    └── CustRun-001/           # First customer (unless --no-structure)

    config/
    ├── cust-run-config.json   # Main configuration
    └── templates.json         # Template definitions

$(_h_bold)EXAMPLES$(_h_reset)
    $(_h_dim)# Quick start with defaults$(_h_reset)
    $script_name init

    $(_h_dim)# Initialize with pentest profile$(_h_reset)
    $script_name init --profile pentest

    $(_h_dim)# Custom path$(_h_reset)
    $script_name init --path ~/Documents/SecurityVault

    $(_h_dim)# Reinitialize existing vault$(_h_reset)
    $script_name init --force
EOF
}

#--------------------------------------
# DOCTOR HELP
#--------------------------------------
help_doctor() {
  local script_name
  script_name="$(basename "${BASH_SOURCE[2]:-$0}")"
  
  cat <<EOF
$(_h_bold)AUTOVAULT - DOCTOR$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $script_name doctor [OPTIONS]

$(_h_bold)DESCRIPTION$(_h_reset)
    Run comprehensive diagnostics on your AutoVault installation.
    Checks dependencies, configuration, structure, permissions, and more.

$(_h_bold)OPTIONS$(_h_reset)
    $(_h_green)--fix$(_h_reset)
        Attempt to automatically fix detected issues

    $(_h_green)--verbose$(_h_reset)
        Show detailed diagnostic information

    $(_h_green)--json$(_h_reset)
        Output results as JSON (for scripting)

$(_h_bold)CHECKS PERFORMED$(_h_reset)
    $(_h_yellow)Dependencies$(_h_reset)
        - Bash version (>= 4.0 required)
        - jq (required for JSON processing)
        - Git, rsync, SSH (optional)

    $(_h_yellow)Configuration$(_h_reset)
        - Config file existence and validity
        - Required fields (vault_root, sections)
        - Templates and remotes configuration

    $(_h_yellow)Vault Structure$(_h_reset)
        - Vault directory existence
        - Customer folders
        - Templates directory
        - Archive directory

    $(_h_yellow)Permissions$(_h_reset)
        - Main script executable
        - Bash scripts executable
        - Hook scripts executable

    $(_h_yellow)Disk Space$(_h_reset)
        - Config directory disk usage
        - Vault directory disk usage

    $(_h_yellow)Integrations$(_h_reset)
        - System alias (av, autovault)
        - Shell completions

$(_h_bold)EXIT CODES$(_h_reset)
    0  All checks passed
    1  One or more checks failed

$(_h_bold)EXAMPLES$(_h_reset)
    $(_h_dim)# Run diagnostics$(_h_reset)
    $script_name doctor

    $(_h_dim)# Run with auto-fix$(_h_reset)
    $script_name doctor --fix

    $(_h_dim)# Get JSON output$(_h_reset)
    $script_name doctor --json
EOF
}

#--------------------------------------
# SEARCH HELP
#--------------------------------------
help_search() {
  local script_name
  script_name="$(basename "${BASH_SOURCE[2]:-$0}")"
  
  cat <<EOF
$(_h_bold)AUTOVAULT - SEARCH$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $script_name search <query> [OPTIONS]

$(_h_bold)DESCRIPTION$(_h_reset)
    Search across all customers and notes in your AutoVault.
    Supports text and regex search with various filters.

$(_h_bold)ARGUMENTS$(_h_reset)
    $(_h_green)<query>$(_h_reset)
        The text or pattern to search for

$(_h_bold)OPTIONS$(_h_reset)
    $(_h_green)-c, --customer <id>$(_h_reset)
        Search only in specific customer

    $(_h_green)-s, --section <name>$(_h_reset)
        Search only in specific section

    $(_h_green)-t, --type <ext>$(_h_reset)
        Filter by file extension (default: md)
        Use 'all' to search all file types

    $(_h_green)-r, --regex$(_h_reset)
        Treat query as regular expression

    $(_h_green)-i, --case-sensitive$(_h_reset)
        Enable case-sensitive search

    $(_h_green)-n, --names-only$(_h_reset)
        Show only matching filenames

    $(_h_green)-C, --context <n>$(_h_reset)
        Lines of context to show (default: 2)

    $(_h_green)-m, --max <n>$(_h_reset)
        Maximum results (default: 100)

    $(_h_green)--json$(_h_reset)
        Output results as JSON

$(_h_bold)EXAMPLES$(_h_reset)
    $(_h_dim)# Search for "password" in all notes$(_h_reset)
    $script_name search password

    $(_h_dim)# Search in specific customer$(_h_reset)
    $script_name search "SQL injection" --customer ACME

    $(_h_dim)# Search with regex$(_h_reset)
    $script_name search "CVE-[0-9]{4}-[0-9]+" --regex

    $(_h_dim)# Search only filenames$(_h_reset)
    $script_name search report --names-only

    $(_h_dim)# Search in reconnaissance section$(_h_reset)
    $script_name search nmap --section Recon

    $(_h_dim)# Case-sensitive with more context$(_h_reset)
    $script_name search TODO --case-sensitive --context 5
EOF
}

#--------------------------------------
# ARCHIVE HELP
#--------------------------------------
help_archive() {
  local script_name
  script_name="$(basename "${BASH_SOURCE[2]:-$0}")"
  
  cat <<EOF
$(_h_bold)AUTOVAULT - ARCHIVE$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $script_name archive <customer_id> [OPTIONS]

$(_h_bold)DESCRIPTION$(_h_reset)
    Archive a customer's data to a compressed file.
    Archives are stored in the vault's _archive directory by default.

    This is useful for:
    - Cleaning up completed engagements
    - Freeing disk space
    - Creating deliverables

$(_h_bold)ARGUMENTS$(_h_reset)
    $(_h_green)<customer_id>$(_h_reset)
        The customer ID to archive (without prefix)

$(_h_bold)OPTIONS$(_h_reset)
    $(_h_green)-r, --remove$(_h_reset)
        Remove customer from vault after archiving

    $(_h_green)-o, --output <path>$(_h_reset)
        Custom output path for the archive file

    $(_h_green)-f, --format <type>$(_h_reset)
        Archive format (default: zip)
        Supported: zip, tar, tar.gz, tar.bz2

    $(_h_green)--no-compress$(_h_reset)
        Create uncompressed tar archive

    $(_h_green)-e, --encrypt$(_h_reset)
        Encrypt archive with password (zip only)

    $(_h_green)--force$(_h_reset)
        Overwrite existing archive without asking

$(_h_bold)OUTPUT$(_h_reset)
    Default archive location:
    vault/_archive/CustRun-<ID>_<DATE>.<format>

$(_h_bold)EXAMPLES$(_h_reset)
    $(_h_dim)# Archive customer ACME$(_h_reset)
    $script_name archive ACME

    $(_h_dim)# Archive and remove from vault$(_h_reset)
    $script_name archive ACME --remove

    $(_h_dim)# Archive with custom format$(_h_reset)
    $script_name archive ACME --format tar.gz

    $(_h_dim)# Archive to specific location$(_h_reset)
    $script_name archive ACME --output ~/backups/acme-archive.zip

    $(_h_dim)# Archive with encryption$(_h_reset)
    $script_name archive ACME --encrypt
EOF
}

#--------------------------------------
# EXPORT HELP
#--------------------------------------
help_export() {
  local script_name
  script_name="$(basename "${BASH_SOURCE[2]:-$0}")"
  
  cat <<EOF
$(_h_bold)AUTOVAULT - EXPORT$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $script_name export <format> [target-type] [target] [OPTIONS]

$(_h_bold)DESCRIPTION$(_h_reset)
    Export vault content to various formats including PDF, HTML,
    and compiled Markdown. Generate professional client reports
    from your notes.

    This is useful for:
    - Creating deliverable reports for clients
    - Sharing documentation offline
    - Archiving vault content in portable formats

$(_h_bold)FORMATS$(_h_reset)
    $(_h_green)pdf$(_h_reset)          Export to PDF document
    $(_h_green)html$(_h_reset)         Export to standalone HTML
    $(_h_green)markdown$(_h_reset)     Export compiled Markdown
    $(_h_green)report$(_h_reset)       Generate professional report

$(_h_bold)TARGET TYPES$(_h_reset)
    $(_h_green)customer <id>$(_h_reset)       Export single customer
    $(_h_green)section <id:name>$(_h_reset)   Export specific section
    $(_h_green)vault$(_h_reset)               Export entire vault
    $(_h_green)file <path>$(_h_reset)         Export single file

$(_h_bold)OPTIONS$(_h_reset)
    $(_h_green)-o, --output <file>$(_h_reset)
        Output file path

    $(_h_green)-t, --template <name>$(_h_reset)
        Report template to use
        Available: default, pentest, audit, summary

    $(_h_green)--no-toc$(_h_reset)
        Disable table of contents

    $(_h_green)--no-metadata$(_h_reset)
        Disable metadata header

    $(_h_green)--page-size <size>$(_h_reset)
        Page size for PDF (A4, Letter, etc.)

    $(_h_green)--css <file>$(_h_reset)
        Custom CSS file for styling

$(_h_bold)TEMPLATES$(_h_reset)
    $(_h_cyan)default$(_h_reset)     Basic report with all content
    $(_h_cyan)pentest$(_h_reset)     Penetration test report format
    $(_h_cyan)audit$(_h_reset)       Security audit format
    $(_h_cyan)summary$(_h_reset)     Brief summary with statistics

$(_h_bold)DEPENDENCIES$(_h_reset)
    - pandoc (required for PDF/HTML conversion)
    - wkhtmltopdf, weasyprint, or texlive (for PDF)

    Install on Debian/Ubuntu:
        sudo apt-get install pandoc wkhtmltopdf

    Install on macOS:
        brew install pandoc wkhtmltopdf

$(_h_bold)EXAMPLES$(_h_reset)
    $(_h_dim)# Export customer to PDF$(_h_reset)
    $script_name export pdf customer 42 -o report.pdf

    $(_h_dim)# Export entire vault to HTML$(_h_reset)
    $script_name export html vault -o vault.html

    $(_h_dim)# Generate pentest report$(_h_reset)
    $script_name export report 42 --template pentest -o pentest-report.pdf

    $(_h_dim)# Export section to markdown$(_h_reset)
    $script_name export markdown section 42:RAISED -o findings.md

    $(_h_dim)# Quick vault export (auto-named)$(_h_reset)
    $script_name export html vault
EOF
}

#--------------------------------------
# GIT-SYNC HELP
#--------------------------------------
help_git_sync() {
  local script_name
  script_name="$(basename "${BASH_SOURCE[2]:-$0}")"
  
  cat <<EOF
$(_h_bold)AUTOVAULT - GIT-SYNC$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $script_name git-sync <command> [OPTIONS]

$(_h_bold)DESCRIPTION$(_h_reset)
    Automatic git synchronization for your vault.
    Commit and push vault modifications automatically.

    This is useful for:
    - Keeping vault changes backed up to a remote repository
    - Syncing vault across multiple machines
    - Maintaining version history of your notes

$(_h_bold)COMMANDS$(_h_reset)
    $(_h_green)status$(_h_reset)              Show git sync status and pending changes
    $(_h_green)now$(_h_reset), $(_h_green)sync$(_h_reset)          Sync immediately (commit + push)
    $(_h_green)watch$(_h_reset)               Watch for changes and sync continuously
    $(_h_green)config$(_h_reset)              Configure git-sync settings
    $(_h_green)enable$(_h_reset) [method]     Enable auto-sync (cron or systemd)
    $(_h_green)disable$(_h_reset)             Disable auto-sync
    $(_h_green)log$(_h_reset) [lines]         Show sync history
    $(_h_green)init$(_h_reset) [remote-url]   Initialize vault as git repository

$(_h_bold)OPTIONS$(_h_reset)
    $(_h_green)-i, --interval <seconds>$(_h_reset)
        Sync interval for watch mode (default: 300)

    $(_h_green)-q, --quiet$(_h_reset)
        Suppress output (for cron jobs)

$(_h_bold)AUTO-SYNC METHODS$(_h_reset)
    $(_h_cyan)cron$(_h_reset)        Uses crontab for periodic sync
    $(_h_cyan)systemd$(_h_reset)     Uses systemd user timer (Linux)

$(_h_bold)COMMIT MESSAGE VARIABLES$(_h_reset)
    {{DATE}}      Current date (YYYY-MM-DD)
    {{TIME}}      Current time (HH:MM:SS)
    {{USER}}      Current username
    {{HOSTNAME}}  Machine hostname

$(_h_bold)CONFIGURATION$(_h_reset)
    Config file: ~/.config/autovault/git-sync.conf
    Log file:    ~/.config/autovault/git-sync.log

$(_h_bold)EXAMPLES$(_h_reset)
    $(_h_dim)# Check current sync status$(_h_reset)
    $script_name git-sync status

    $(_h_dim)# Sync now (commit and push)$(_h_reset)
    $script_name git-sync now

    $(_h_dim)# Watch for changes (sync every 2 minutes)$(_h_reset)
    $script_name git-sync watch --interval 120

    $(_h_dim)# Enable automatic sync via cron$(_h_reset)
    $script_name git-sync enable cron

    $(_h_dim)# Initialize vault as git repo$(_h_reset)
    $script_name git-sync init https://github.com/user/vault.git

    $(_h_dim)# View sync log$(_h_reset)
    $script_name git-sync log 50

$(_h_bold)SETUP GUIDE$(_h_reset)
    1. Initialize git in your vault (if not already):
       $script_name git-sync init

    2. Add remote repository:
       cd /path/to/vault && git remote add origin <url>

    3. Configure sync settings:
       $script_name git-sync config

    4. Enable automatic sync:
       $script_name git-sync enable cron
EOF
}

#--------------------------------------
# THEME HELP
#--------------------------------------
help_theme() {
  local script_name
  script_name="$(basename "${BASH_SOURCE[2]:-$0}")"
  
  cat <<EOF
$(_h_bold)AUTOVAULT - THEME$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $script_name theme [SUBCOMMAND]

$(_h_bold)DESCRIPTION$(_h_reset)
    Configure AutoVault's color theme and UI preferences.
    Theme settings are saved to ~/.config/autovault/theme.conf

$(_h_bold)SUBCOMMANDS$(_h_reset)
    $(_h_green)status$(_h_reset)     Show current theme settings (default)
    $(_h_green)set$(_h_reset)        Set theme (dark/light/auto)
    $(_h_green)preview$(_h_reset)    Preview all available themes
    $(_h_green)config$(_h_reset)     Interactive theme configuration
    $(_h_green)reset$(_h_reset)      Reset to default settings

$(_h_bold)THEMES$(_h_reset)
    $(_h_cyan)dark$(_h_reset)       Optimized for dark terminal backgrounds (default)
    $(_h_cyan)light$(_h_reset)      Optimized for light terminal backgrounds  
    $(_h_cyan)auto$(_h_reset)       Auto-detect based on terminal settings

$(_h_bold)ENVIRONMENT$(_h_reset)
    $(_h_green)AUTOVAULT_THEME$(_h_reset)    Override theme (dark/light/auto)
    $(_h_green)AUTOVAULT_NOTIFY$(_h_reset)   Enable desktop notifications (true/false)
    $(_h_green)NO_COLOR$(_h_reset)           Disable all colors

$(_h_bold)EXAMPLES$(_h_reset)
    $(_h_dim)# Show current theme settings$(_h_reset)
    $script_name theme

    $(_h_dim)# Set light theme$(_h_reset)
    $script_name theme set light

    $(_h_dim)# Preview all themes$(_h_reset)
    $script_name theme preview

    $(_h_dim)# Interactive configuration$(_h_reset)
    $script_name theme config
EOF
}

#--------------------------------------
# DEMO HELP
#--------------------------------------
help_demo() {
  local script_name
  script_name="$(basename "${BASH_SOURCE[2]:-$0}")"
  
  cat <<EOF
$(_h_bold)AUTOVAULT - DEMO$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $script_name demo [COMPONENT]

$(_h_bold)DESCRIPTION$(_h_reset)
    Demonstrate AutoVault's UI components and features.
    Useful for testing themes and terminal compatibility.

$(_h_bold)COMPONENTS$(_h_reset)
    $(_h_green)all$(_h_reset)        Run all demos (default)
    $(_h_green)progress$(_h_reset)   Progress bar demonstration
    $(_h_green)spinner$(_h_reset)    Spinner/loading animations
    $(_h_green)theme$(_h_reset)      Theme switching preview
    $(_h_green)menu$(_h_reset)       Interactive menu selection
    $(_h_green)notify$(_h_reset)     Desktop notifications
    $(_h_green)box$(_h_reset)        Box and section formatting

$(_h_bold)EXAMPLES$(_h_reset)
    $(_h_dim)# Run all demos$(_h_reset)
    $script_name demo

    $(_h_dim)# Show progress bar demo$(_h_reset)
    $script_name demo progress

    $(_h_dim)# Test spinner animations$(_h_reset)
    $script_name demo spinner

    $(_h_dim)# Preview themes$(_h_reset)
    $script_name demo theme
EOF
}

#--------------------------------------
# VAULTS (MULTI-VAULT) HELP
#--------------------------------------
help_vaults() {
  local script_name
  script_name="$(basename "${BASH_SOURCE[2]:-$0}")"
  
  cat <<EOF
$(_h_bold)AUTOVAULT - VAULTS (MULTI-VAULT)$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $script_name vaults <command> [args]

$(_h_bold)DESCRIPTION$(_h_reset)
    Manage multiple AutoVault configurations. Each profile points
    to a different Obsidian vault with its own settings.

$(_h_bold)COMMANDS$(_h_reset)
    $(_h_green)list$(_h_reset)              List all vault profiles
    $(_h_green)add$(_h_reset) <name> <path> Add a new vault profile
    $(_h_green)remove$(_h_reset) <name>     Remove a vault profile
    $(_h_green)switch$(_h_reset) <name>     Switch to a different vault
    $(_h_green)current$(_h_reset)           Show current active vault
    $(_h_green)info$(_h_reset) [name]       Show vault details

$(_h_bold)EXAMPLES$(_h_reset)
    $(_h_dim)# Add vaults$(_h_reset)
    $script_name vaults add work ~/Documents/WorkVault
    $script_name vaults add personal ~/Obsidian/Personal

    $(_h_dim)# Switch between vaults$(_h_reset)
    $script_name vaults switch work
    $script_name vaults switch personal

    $(_h_dim)# Check current vault$(_h_reset)
    $script_name vaults current
EOF
}

#--------------------------------------
# PLUGINS HELP
#--------------------------------------
help_plugins() {
  local script_name
  script_name="$(basename "${BASH_SOURCE[2]:-$0}")"
  
  cat <<EOF
$(_h_bold)AUTOVAULT - PLUGINS$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $script_name plugins <command> [args]

$(_h_bold)DESCRIPTION$(_h_reset)
    Extend AutoVault with custom plugins. Plugins can hook into
    events and add custom commands.

$(_h_bold)COMMANDS$(_h_reset)
    $(_h_green)list$(_h_reset)              List installed plugins
    $(_h_green)info$(_h_reset) <name>       Show plugin details
    $(_h_green)enable$(_h_reset) <name>     Enable a plugin
    $(_h_green)disable$(_h_reset) <name>    Disable a plugin
    $(_h_green)create$(_h_reset) <name>     Create a new plugin
    $(_h_green)run$(_h_reset) <p> <cmd>     Run a plugin command

$(_h_bold)PLUGIN EVENTS$(_h_reset)
    on-init             AutoVault starts
    on-customer-create  After customer creation
    on-customer-remove  Before customer removal
    on-template-apply   After templates applied
    on-backup-create    After backup created
    on-vault-switch     When switching vaults

$(_h_bold)EXAMPLES$(_h_reset)
    $(_h_dim)# Create a new plugin$(_h_reset)
    $script_name plugins create my-plugin

    $(_h_dim)# Enable/disable$(_h_reset)
    $script_name plugins enable my-plugin
    $script_name plugins disable my-plugin

    $(_h_dim)# Run plugin command$(_h_reset)
    $script_name plugins run my-plugin my-command arg1
EOF
}

#--------------------------------------
# ENCRYPT HELP
#--------------------------------------
help_encrypt() {
  local script_name
  script_name="$(basename "${BASH_SOURCE[2]:-$0}")"
  
  cat <<EOF
$(_h_bold)AUTOVAULT - ENCRYPTION$(_h_reset)

$(_h_bold)SYNOPSIS$(_h_reset)
    $script_name encrypt <command> [args]

$(_h_bold)DESCRIPTION$(_h_reset)
    Encrypt and decrypt sensitive notes in your vault.
    Supports 'age' (recommended) or GPG encryption.

$(_h_bold)COMMANDS$(_h_reset)
    $(_h_green)init$(_h_reset)              Initialize encryption (generate keys)
    $(_h_green)encrypt$(_h_reset) <path>    Encrypt a file or folder
    $(_h_green)decrypt$(_h_reset) <path>    Decrypt a file or folder
    $(_h_green)status$(_h_reset)            Show encryption status
    $(_h_green)lock$(_h_reset)              Encrypt all _private folders
    $(_h_green)unlock$(_h_reset)            Decrypt all _private folders

$(_h_bold)BACKENDS$(_h_reset)
    $(_h_green)age$(_h_reset) (recommended) - Modern, simple encryption
    $(_h_green)gpg$(_h_reset)               - Traditional GPG encryption

$(_h_bold)EXAMPLES$(_h_reset)
    $(_h_dim)# First time setup$(_h_reset)
    $script_name encrypt init

    $(_h_dim)# Encrypt a file$(_h_reset)
    $script_name encrypt encrypt path/to/secret.md

    $(_h_dim)# Lock all private notes before commit$(_h_reset)
    $script_name encrypt lock

    $(_h_dim)# Unlock for editing$(_h_reset)
    $script_name encrypt unlock
EOF
}
