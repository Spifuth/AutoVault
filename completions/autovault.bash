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
    local commands="config validate status diff stats structure templates test cleanup customer section backup vault remote hooks requirements help"
    
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
        
        structure|new)
            COMPREPLY=($(compgen -W "--help" -- "$cur"))
            ;;
        
        config|setup|init)
            COMPREPLY=($(compgen -W "--help" -- "$cur"))
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

# Register completion for multiple command names
complete -F _autovault_completions cust-run-config.sh
complete -F _autovault_completions cust-run-config
complete -F _autovault_completions autovault
