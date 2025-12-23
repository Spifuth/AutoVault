#!/usr/bin/env bash
#===============================================================================
#
#  SCRIPT NAME:    Manage-Plugins.sh
#  DESCRIPTION:    Manage AutoVault plugins - list, enable, disable, create
#
#  USAGE:          ./Manage-Plugins.sh <subcommand> [options]
#
#  SUBCOMMANDS:    list        List all plugins
#                  info        Show plugin details
#                  enable      Enable a plugin
#                  disable     Disable a plugin
#                  create      Create a new plugin
#                  run         Run a plugin command
#
#  AUTHOR:         AutoVault Project
#  VERSION:        2.4.0
#
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/plugins.sh"

# Source UI library if available
if [[ -f "$SCRIPT_DIR/lib/ui.sh" ]]; then
    source "$SCRIPT_DIR/lib/ui.sh"
    UI_AVAILABLE=true
else
    UI_AVAILABLE=false
fi

#--------------------------------------
# USAGE
#--------------------------------------
usage() {
  cat << EOF
${BOLD:-}USAGE${NC:-}
    $(basename "$0") <SUBCOMMAND> [OPTIONS]

${BOLD:-}DESCRIPTION${NC:-}
    Manage AutoVault plugins. Plugins extend functionality through
    event handlers and custom commands.

${BOLD:-}SUBCOMMANDS${NC:-}
    list                    List all installed plugins
    info <name>             Show detailed plugin information
    enable <name>           Enable a disabled plugin
    disable <name>          Disable a plugin
    create <name>           Create a new plugin from template
    run <plugin> <cmd>      Run a plugin command

${BOLD:-}OPTIONS${NC:-}
    -h, --help              Show this help message

${BOLD:-}EXAMPLES${NC:-}
    # List all plugins
    $(basename "$0") list

    # Show plugin info
    $(basename "$0") info my-plugin

    # Enable/disable
    $(basename "$0") enable my-plugin
    $(basename "$0") disable my-plugin

    # Create a new plugin
    $(basename "$0") create my-new-plugin

    # Run plugin command
    $(basename "$0") run my-plugin my-command arg1 arg2

${BOLD:-}PLUGIN EVENTS${NC:-}
    on-init               When AutoVault starts
    on-customer-create    After customer creation
    on-customer-remove    Before customer removal
    on-template-apply     After templates applied
    on-section-add        After section added
    on-backup-create      After backup created
    on-vault-switch       When switching vaults

${BOLD:-}CONFIGURATION${NC:-}
    Plugins directory: $PLUGINS_DIR

EOF
}

#--------------------------------------
# LIST PLUGINS
#--------------------------------------
cmd_list() {
    if [[ ! -d "$PLUGINS_DIR" ]]; then
        echo "No plugins installed."
        echo ""
        echo "Create one with: $(basename "$0") create <name>"
        return 0
    fi
    
    local plugins=()
    for plugin_dir in "$PLUGINS_DIR"/*/; do
        [[ -d "$plugin_dir" ]] || continue
        plugins+=("$(basename "$plugin_dir")")
    done
    
    if [[ ${#plugins[@]} -eq 0 ]]; then
        echo "No plugins installed."
        echo ""
        echo "Create one with: $(basename "$0") create <name>"
        return 0
    fi
    
    if [[ "$UI_AVAILABLE" == "true" ]]; then
        print_section "Installed Plugins"
        echo ""
    else
        echo "Installed Plugins:"
        echo "------------------"
    fi
    
    for plugin in "${plugins[@]}"; do
        local metadata="$PLUGINS_DIR/$plugin/plugin.json"
        
        if [[ -f "$metadata" ]]; then
            local version description enabled
            version=$(jq -r '.version // "?"' "$metadata")
            description=$(jq -r '.description // ""' "$metadata")
            enabled=$(jq -r '.enabled // true' "$metadata")
            
            local status=""
            if [[ "$enabled" == "false" ]]; then
                status="${RED:-}[disabled]${NC:-}"
            else
                status="${GREEN:-}[enabled]${NC:-}"
            fi
            
            if [[ "$UI_AVAILABLE" == "true" ]]; then
                printf "  ${THEME[accent]}%-20s${THEME[reset]} v%-8s %s\n" "$plugin" "$version" "$status"
                if [[ -n "$description" ]]; then
                    echo -e "    ${THEME[muted]}$description${THEME[reset]}"
                fi
            else
                printf "  %-20s v%-8s %s\n" "$plugin" "$version" "$status"
                if [[ -n "$description" ]]; then
                    echo "    $description"
                fi
            fi
        else
            echo "  $plugin (missing metadata)"
        fi
    done
    
    echo ""
    echo "Total: ${#plugins[@]} plugin(s)"
}

#--------------------------------------
# INFO
#--------------------------------------
cmd_info() {
    local plugin_name="${1:-}"
    
    if [[ -z "$plugin_name" ]]; then
        log_error "Plugin name required"
        echo "Usage: $(basename "$0") info <name>"
        exit 1
    fi
    
    local metadata="$PLUGINS_DIR/$plugin_name/plugin.json"
    
    if [[ ! -f "$metadata" ]]; then
        log_error "Plugin not found: $plugin_name"
        exit 1
    fi
    
    if [[ "$UI_AVAILABLE" == "true" ]]; then
        print_section "Plugin: $plugin_name"
        echo ""
        
        local version description author enabled
        version=$(jq -r '.version // "?"' "$metadata")
        description=$(jq -r '.description // ""' "$metadata")
        author=$(jq -r '.author // "Unknown"' "$metadata")
        enabled=$(jq -r '.enabled // true' "$metadata")
        
        print_kv "Version" "$version"
        print_kv "Author" "$author"
        print_kv "Status" "$([ "$enabled" == "true" ] && echo "Enabled" || echo "Disabled")"
        
        if [[ -n "$description" ]]; then
            echo ""
            echo -e "${THEME[muted]}$description${THEME[reset]}"
        fi
        
        echo ""
        echo "Events:"
        jq -r '.events[]? // empty' "$metadata" 2>/dev/null | while read -r event; do
            local handler="$PLUGINS_DIR/$plugin_name/$event.sh"
            if [[ -f "$handler" ]]; then
                echo -e "  ${THEME[success]}✓${THEME[reset]} $event"
            else
                echo -e "  ${THEME[warning]}○${THEME[reset]} $event ${THEME[muted]}(no handler)${THEME[reset]}"
            fi
        done
        
        echo ""
        echo "Commands:"
        if [[ -d "$PLUGINS_DIR/$plugin_name/commands" ]]; then
            for cmd_file in "$PLUGINS_DIR/$plugin_name/commands"/*.sh; do
                [[ -f "$cmd_file" ]] || continue
                local cmd_name=$(basename "$cmd_file" .sh)
                echo "  - $cmd_name"
            done
        else
            echo "  (none)"
        fi
    else
        jq '.' "$metadata"
    fi
}

#--------------------------------------
# ENABLE
#--------------------------------------
cmd_enable() {
    local plugin_name="${1:-}"
    
    if [[ -z "$plugin_name" ]]; then
        log_error "Plugin name required"
        exit 1
    fi
    
    plugin_enable "$plugin_name"
}

#--------------------------------------
# DISABLE
#--------------------------------------
cmd_disable() {
    local plugin_name="${1:-}"
    
    if [[ -z "$plugin_name" ]]; then
        log_error "Plugin name required"
        exit 1
    fi
    
    plugin_disable "$plugin_name"
}

#--------------------------------------
# CREATE
#--------------------------------------
cmd_create() {
    local plugin_name="${1:-}"
    
    if [[ -z "$plugin_name" ]]; then
        log_error "Plugin name required"
        echo "Usage: $(basename "$0") create <name>"
        exit 1
    fi
    
    # Validate name
    if [[ ! "$plugin_name" =~ ^[a-z0-9_-]+$ ]]; then
        log_error "Invalid plugin name. Use lowercase letters, numbers, dashes, and underscores."
        exit 1
    fi
    
    plugin_create "$plugin_name"
    
    log_success "Plugin created: $plugin_name"
    echo ""
    echo "Next steps:"
    echo "  1. Edit $PLUGINS_DIR/$plugin_name/plugin.json"
    echo "  2. Add event handlers in $PLUGINS_DIR/$plugin_name/"
    echo "  3. Add commands in $PLUGINS_DIR/$plugin_name/commands/"
    echo ""
    echo "Documentation: https://github.com/your-repo/autovault/wiki/Plugins"
}

#--------------------------------------
# RUN
#--------------------------------------
cmd_run() {
    local plugin_name="${1:-}"
    local command_name="${2:-}"
    shift 2 || true
    
    if [[ -z "$plugin_name" ]]; then
        log_error "Plugin name required"
        echo "Usage: $(basename "$0") run <plugin> <command> [args...]"
        exit 1
    fi
    
    if [[ -z "$command_name" ]]; then
        log_error "Command name required"
        echo "Usage: $(basename "$0") run <plugin> <command> [args...]"
        echo ""
        echo "Available commands for $plugin_name:"
        if [[ -d "$PLUGINS_DIR/$plugin_name/commands" ]]; then
            for cmd_file in "$PLUGINS_DIR/$plugin_name/commands"/*.sh; do
                [[ -f "$cmd_file" ]] || continue
                echo "  - $(basename "$cmd_file" .sh)"
            done
        else
            echo "  (none)"
        fi
        exit 1
    fi
    
    plugin_run_command "$plugin_name" "$command_name" "$@"
}

#--------------------------------------
# MAIN
#--------------------------------------
main() {
    local cmd="${1:-}"
    shift || true
    
    case "$cmd" in
        -h|--help|help|"")
            usage
            ;;
        list|ls)
            cmd_list
            ;;
        info|show)
            cmd_info "$@"
            ;;
        enable)
            cmd_enable "$@"
            ;;
        disable)
            cmd_disable "$@"
            ;;
        create|new)
            cmd_create "$@"
            ;;
        run|exec)
            cmd_run "$@"
            ;;
        *)
            log_error "Unknown command: $cmd"
            usage
            exit 1
            ;;
    esac
}

main "$@"
