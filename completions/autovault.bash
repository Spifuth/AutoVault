#!/usr/bin/env bash
#===============================================================================
#
#  AUTOVAULT - Bash Completion
#
#===============================================================================
#
#  DESCRIPTION:    Bash completion script for AutoVault CLI.
#                  Provides intelligent tab-completion for commands,
#                  subcommands, options, and dynamic values.
#
#  INSTALLATION:   
#                  # Option 1: Source in your .bashrc
#                  source /path/to/autovault.bash
#
#                  # Option 2: System-wide (Linux)
#                  sudo cp autovault.bash /etc/bash_completion.d/autovault
#
#                  # Option 3: User-local (Linux/macOS)
#                  mkdir -p ~/.local/share/bash-completion/completions
#                  cp autovault.bash ~/.local/share/bash-completion/completions/cust-run-config.sh
#
#  COMPLETIONS:    - Main commands (structure, templates, customer, etc.)
#                  - Subcommands (add, remove, list, sync, apply, etc.)
#                  - Global options (--verbose, --dry-run, --help, etc.)
#                  - Dynamic customer IDs from config
#                  - Dynamic section names from config
#                  - Backup file names
#
#===============================================================================

_autovault_completions() {
    local cur prev words cword
    _init_completion || return
    
    # All main commands
    local commands="config validate status diff stats structure templates test cleanup customer section backup vault remote hooks completions alias requirements help init doctor search archive export git-sync nmap theme demo vaults plugins encrypt"
    
    # Global options
    local global_opts="-v --verbose -q --quiet --silent --no-color --dry-run --diff -h --help --version"
    
    # Subcommands for each command
    local customer_cmds="add remove list export import clone"
    local section_cmds="add remove list"
    local backup_cmds="create list restore cleanup"
    local templates_cmds="sync apply export preview list"
    local vault_cmds="init plugins check hub"
    local hooks_cmds="list init test"
    local remote_cmds="list init add remove test push pull status"
    local completions_cmds="install uninstall status"
    local alias_cmds="install uninstall status"
    local theme_cmds="status set preview config reset"
    local demo_cmds="all progress spinner theme menu notify box"
    local vaults_cmds="list add remove switch current info"
    local plugins_cmds="list info enable disable create run"
    local encrypt_cmds="init encrypt decrypt status lock unlock"
    local export_cmds="pdf html markdown report"
    local export_targets="customer section vault file"
    local git_sync_cmds="status now sync watch config enable disable log init"
    local nmap_cmds="import parse templates"
    
    # Get the main command (skip options)
    local main_cmd=""
    local i
    for ((i=1; i < cword; i++)); do
        case "${words[i]}" in
            -*)
                continue
                ;;
            *)
                main_cmd="${words[i]}"
                break
                ;;
        esac
    done
    
    # If we're completing the first non-option word, suggest commands
    if [[ -z "$main_cmd" ]]; then
        if [[ "$cur" == -* ]]; then
            COMPREPLY=($(compgen -W "$global_opts" -- "$cur"))
        else
            COMPREPLY=($(compgen -W "$commands" -- "$cur"))
        fi
        return
    fi
    
    # Complete based on main command
    case "$main_cmd" in
        customer|customers)
            case "$prev" in
                add|remove)
                    # Suggest existing customer IDs from config
                    local ids=$(_autovault_get_customer_ids)
                    COMPREPLY=($(compgen -W "$ids" -- "$cur"))
                    ;;
                customer|customers)
                    COMPREPLY=($(compgen -W "$customer_cmds --help" -- "$cur"))
                    ;;
                *)
                    COMPREPLY=($(compgen -W "$customer_cmds --help" -- "$cur"))
                    ;;
            esac
            ;;
        
        section|sections)
            case "$prev" in
                add|remove)
                    # Suggest existing section names from config
                    local sections=$(_autovault_get_sections)
                    COMPREPLY=($(compgen -W "$sections" -- "$cur"))
                    ;;
                section|sections)
                    COMPREPLY=($(compgen -W "$section_cmds --help" -- "$cur"))
                    ;;
                *)
                    COMPREPLY=($(compgen -W "$section_cmds --help" -- "$cur"))
                    ;;
            esac
            ;;
        
        backup|backups)
            case "$prev" in
                restore|cleanup)
                    # Suggest available backup files
                    local backups=$(_autovault_get_backups)
                    COMPREPLY=($(compgen -W "$backups" -- "$cur"))
                    ;;
                backup|backups)
                    COMPREPLY=($(compgen -W "$backup_cmds --help" -- "$cur"))
                    ;;
                *)
                    COMPREPLY=($(compgen -W "$backup_cmds --help" -- "$cur"))
                    ;;
            esac
            ;;
        
        templates|apply)
            case "$prev" in
                preview)
                    # Suggest template names
                    local templates=$(_autovault_get_templates)
                    COMPREPLY=($(compgen -W "$templates" -- "$cur"))
                    ;;
                templates|apply)
                    COMPREPLY=($(compgen -W "$templates_cmds --help" -- "$cur"))
                    ;;
                *)
                    COMPREPLY=($(compgen -W "$templates_cmds --help" -- "$cur"))
                    ;;
            esac
            ;;
        
        vault)
            COMPREPLY=($(compgen -W "$vault_cmds --help" -- "$cur"))
            ;;
        
        hooks)
            case "$prev" in
                test)
                    # Suggest available hooks
                    COMPREPLY=($(compgen -W "pre-customer-remove post-customer-remove post-templates-apply on-error" -- "$cur"))
                    ;;
                hooks)
                    COMPREPLY=($(compgen -W "$hooks_cmds --help" -- "$cur"))
                    ;;
                *)
                    COMPREPLY=($(compgen -W "$hooks_cmds --help" -- "$cur"))
                    ;;
            esac
            ;;
        
        remote)
            case "$prev" in
                remove|rm|test|push|pull|status)
                    # Suggest configured remotes
                    local remotes=$(_autovault_get_remotes)
                    COMPREPLY=($(compgen -W "$remotes" -- "$cur"))
                    ;;
                remote)
                    COMPREPLY=($(compgen -W "$remote_cmds --help" -- "$cur"))
                    ;;
                *)
                    COMPREPLY=($(compgen -W "$remote_cmds --help" -- "$cur"))
                    ;;
            esac
            ;;
        
        completions)
            case "$prev" in
                install)
                    COMPREPLY=($(compgen -W "bash zsh all --user --system" -- "$cur"))
                    ;;
                uninstall)
                    COMPREPLY=($(compgen -W "bash zsh all" -- "$cur"))
                    ;;
                completions)
                    COMPREPLY=($(compgen -W "$completions_cmds --help" -- "$cur"))
                    ;;
                *)
                    COMPREPLY=($(compgen -W "$completions_cmds --help" -- "$cur"))
                    ;;
            esac
            ;;
        
        alias)
            case "$prev" in
                install)
                    COMPREPLY=($(compgen -W "autovault av vault custrun --name= --method=symlink --method=alias --user --system" -- "$cur"))
                    ;;
                uninstall)
                    COMPREPLY=($(compgen -W "--all --name=" -- "$cur"))
                    ;;
                alias)
                    COMPREPLY=($(compgen -W "$alias_cmds --help" -- "$cur"))
                    ;;
                *)
                    COMPREPLY=($(compgen -W "$alias_cmds --help" -- "$cur"))
                    ;;
            esac
            ;;
        
        structure|new)
            COMPREPLY=($(compgen -W "--help" -- "$cur"))
            ;;
        
        config|setup)
            COMPREPLY=($(compgen -W "--help" -- "$cur"))
            ;;
        
        init)
            case "$prev" in
                --profile)
                    COMPREPLY=($(compgen -W "minimal pentest audit bugbounty" -- "$cur"))
                    ;;
                --path)
                    _filedir -d
                    ;;
                init)
                    COMPREPLY=($(compgen -W "--path --profile --force --no-structure --help" -- "$cur"))
                    ;;
                *)
                    COMPREPLY=($(compgen -W "--path --profile --force --no-structure --help" -- "$cur"))
                    ;;
            esac
            ;;
        
        doctor|diagnose|check)
            COMPREPLY=($(compgen -W "--fix --verbose --json --help" -- "$cur"))
            ;;
        
        search|find|grep)
            case "$prev" in
                -c|--customer)
                    local ids=$(_autovault_get_customer_ids)
                    COMPREPLY=($(compgen -W "$ids" -- "$cur"))
                    ;;
                -s|--section)
                    local sections=$(_autovault_get_sections)
                    COMPREPLY=($(compgen -W "$sections" -- "$cur"))
                    ;;
                -t|--type)
                    COMPREPLY=($(compgen -W "md txt all json yaml" -- "$cur"))
                    ;;
                -C|--context|-m|--max)
                    COMPREPLY=()  # Numbers
                    ;;
                *)
                    COMPREPLY=($(compgen -W "-c --customer -s --section -t --type -r --regex -i --case-sensitive -n --names-only -C --context -m --max --json --help" -- "$cur"))
                    ;;
            esac
            ;;
        
        archive)
            case "$prev" in
                -f|--format)
                    COMPREPLY=($(compgen -W "zip tar tar.gz tar.bz2" -- "$cur"))
                    ;;
                -o|--output)
                    _filedir
                    ;;
                archive)
                    local ids=$(_autovault_get_customer_ids)
                    COMPREPLY=($(compgen -W "$ids -r --remove -o --output -f --format --no-compress -e --encrypt --force --help" -- "$cur"))
                    ;;
                *)
                    COMPREPLY=($(compgen -W "-r --remove -o --output -f --format --no-compress -e --encrypt --force --help" -- "$cur"))
                    ;;
            esac
            ;;
        
        theme)
            case "$prev" in
                set)
                    COMPREPLY=($(compgen -W "dark light auto" -- "$cur"))
                    ;;
                theme)
                    COMPREPLY=($(compgen -W "$theme_cmds --help" -- "$cur"))
                    ;;
                *)
                    COMPREPLY=($(compgen -W "$theme_cmds --help" -- "$cur"))
                    ;;
            esac
            ;;
        
        demo)
            COMPREPLY=($(compgen -W "$demo_cmds --help" -- "$cur"))
            ;;
        
        vaults|vault-switch)
            case "$prev" in
                switch|use|select|remove|rm|info|show)
                    # Suggest configured vault profiles
                    local vaults=$(_autovault_get_vaults)
                    COMPREPLY=($(compgen -W "$vaults" -- "$cur"))
                    ;;
                add)
                    # First arg is name, second is path
                    _filedir -d
                    ;;
                vaults|vault-switch)
                    COMPREPLY=($(compgen -W "$vaults_cmds --help" -- "$cur"))
                    ;;
                *)
                    COMPREPLY=($(compgen -W "$vaults_cmds --help" -- "$cur"))
                    ;;
            esac
            ;;
        
        plugins|plugin)
            case "$prev" in
                info|show|enable|disable)
                    # Suggest installed plugins
                    local plugins=$(_autovault_get_plugins)
                    COMPREPLY=($(compgen -W "$plugins" -- "$cur"))
                    ;;
                run|exec)
                    local plugins=$(_autovault_get_plugins)
                    COMPREPLY=($(compgen -W "$plugins" -- "$cur"))
                    ;;
                plugins|plugin)
                    COMPREPLY=($(compgen -W "$plugins_cmds --help" -- "$cur"))
                    ;;
                *)
                    COMPREPLY=($(compgen -W "$plugins_cmds --help" -- "$cur"))
                    ;;
            esac
            ;;
        
        encrypt|encryption|crypto)
            case "$prev" in
                encrypt|enc|decrypt|dec)
                    _filedir
                    ;;
                init|setup)
                    COMPREPLY=($(compgen -W "--password -p --backend" -- "$cur"))
                    ;;
                --backend|-b)
                    COMPREPLY=($(compgen -W "age gpg" -- "$cur"))
                    ;;
                encrypt|encryption|crypto)
                    COMPREPLY=($(compgen -W "$encrypt_cmds --help" -- "$cur"))
                    ;;
                *)
                    COMPREPLY=($(compgen -W "$encrypt_cmds --help" -- "$cur"))
                    ;;
            esac
            ;;
        
        export)
            case "$prev" in
                pdf|html|markdown|report)
                    COMPREPLY=($(compgen -W "$export_targets" -- "$cur"))
                    ;;
                customer)
                    local ids=$(_autovault_get_customer_ids)
                    COMPREPLY=($(compgen -W "$ids" -- "$cur"))
                    ;;
                -t|--template)
                    COMPREPLY=($(compgen -W "default pentest audit summary" -- "$cur"))
                    ;;
                -o|--output)
                    _filedir
                    ;;
                --page-size)
                    COMPREPLY=($(compgen -W "A4 Letter Legal A3" -- "$cur"))
                    ;;
                export)
                    COMPREPLY=($(compgen -W "$export_cmds --help" -- "$cur"))
                    ;;
                *)
                    COMPREPLY=($(compgen -W "-o --output -t --template --no-toc --no-metadata --page-size --css --help" -- "$cur"))
                    ;;
            esac
            ;;
        
        git-sync|gitsync|sync)
            case "$prev" in
                enable)
                    COMPREPLY=($(compgen -W "cron systemd" -- "$cur"))
                    ;;
                watch)
                    COMPREPLY=($(compgen -W "--interval -i" -- "$cur"))
                    ;;
                log|logs|history)
                    COMPREPLY=($(compgen -W "10 20 50 100" -- "$cur"))
                    ;;
                init)
                    # Could suggest common git providers
                    ;;
                git-sync|gitsync|sync)
                    COMPREPLY=($(compgen -W "$git_sync_cmds --help" -- "$cur"))
                    ;;
                *)
                    COMPREPLY=($(compgen -W "$git_sync_cmds --quiet -q --help" -- "$cur"))
                    ;;
            esac
            ;;
        
        nmap|import-nmap)
            case "$prev" in
                --customer|-c)
                    local customers=$(_autovault_get_customer_ids)
                    COMPREPLY=($(compgen -W "$customers" -- "$cur"))
                    ;;
                --format|-f)
                    COMPREPLY=($(compgen -W "xml gnmap grepable" -- "$cur"))
                    ;;
                --output-dir|-o)
                    COMPREPLY=($(compgen -d -- "$cur"))
                    ;;
                --file|import)
                    COMPREPLY=($(compgen -f -X '!*.@(xml|gnmap)' -- "$cur"))
                    ;;
                nmap|import-nmap)
                    COMPREPLY=($(compgen -W "$nmap_cmds --help" -- "$cur"))
                    ;;
                *)
                    COMPREPLY=($(compgen -W "$nmap_cmds --customer -c --format -f --output-dir -o --quiet -q --help" -- "$cur"))
                    ;;
            esac
            ;;
        
        validate|status|test|cleanup|requirements)
            COMPREPLY=($(compgen -W "--help" -- "$cur"))
            ;;
        
        *)
            # Default: suggest global options
            if [[ "$cur" == -* ]]; then
                COMPREPLY=($(compgen -W "$global_opts" -- "$cur"))
            fi
            ;;
    esac
}

# Helper: Get customer IDs from config
_autovault_get_customer_ids() {
    local config_file="${CONFIG_JSON:-./config/cust-run-config.json}"
    if [[ -f "$config_file" ]] && command -v jq &>/dev/null; then
        jq -r '.CustomerIds[]? // empty' "$config_file" 2>/dev/null
    fi
}

# Helper: Get sections from config
_autovault_get_sections() {
    local config_file="${CONFIG_JSON:-./config/cust-run-config.json}"
    if [[ -f "$config_file" ]] && command -v jq &>/dev/null; then
        jq -r '.Sections[]? // empty' "$config_file" 2>/dev/null
    fi
}

# Helper: Get backup files
_autovault_get_backups() {
    local backup_dir="./backups"
    if [[ -d "$backup_dir" ]]; then
        find "$backup_dir" -maxdepth 1 -name "*.json" -printf "%f\n" 2>/dev/null | sed 's/\.json$//'
    fi
}

# Helper: Get configured remotes
_autovault_get_remotes() {
    local config_file="${REMOTES_JSON:-./config/remotes.json}"
    if [[ -f "$config_file" ]] && command -v jq &>/dev/null; then
        jq -r '.remotes | keys[]' "$config_file" 2>/dev/null
    fi
}

# Helper: Get template names
_autovault_get_templates() {
    local config_file="${CONFIG_JSON:-./config/templates.json}"
    if [[ -f "$config_file" ]] && command -v jq &>/dev/null; then
        jq -r 'keys[]' "$config_file" 2>/dev/null
    fi
}

# Helper: Get vault profiles
_autovault_get_vaults() {
    local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/autovault/vaults.json"
    if [[ -f "$config_file" ]] && command -v jq &>/dev/null; then
        jq -r '.vaults | keys[]' "$config_file" 2>/dev/null
    fi
}

# Helper: Get installed plugins
_autovault_get_plugins() {
    local plugins_dir="${PLUGINS_DIR:-./plugins}"
    if [[ -d "$plugins_dir" ]]; then
        find "$plugins_dir" -maxdepth 1 -type d -printf "%f\n" 2>/dev/null | tail -n +2
    fi
}

# Register completion for multiple command names (including common aliases)
complete -F _autovault_completions cust-run-config.sh
complete -F _autovault_completions cust-run-config
complete -F _autovault_completions autovault
complete -F _autovault_completions av
complete -F _autovault_completions vault
complete -F _autovault_completions custrun
