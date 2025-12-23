#!/usr/bin/env bash
#===============================================================================
#
#  AUTOVAULT - plugins.sh (Library)
#
#===============================================================================
#
#  DESCRIPTION:    Plugin system for AutoVault. Allows extending functionality
#                  through modular, event-driven plugins.
#
#  PLUGIN STRUCTURE:
#     plugins/
#       ├── my-plugin/
#       │   ├── plugin.json      # Plugin metadata
#       │   ├── init.sh          # Initialization script
#       │   ├── on-customer-create.sh  # Event handler
#       │   └── commands/        # Custom commands
#       │       └── my-command.sh
#
#  PLUGIN.JSON:
#     {
#       "name": "my-plugin",
#       "version": "1.0.0",
#       "description": "My custom plugin",
#       "author": "Your Name",
#       "events": ["on-customer-create", "on-template-apply"],
#       "commands": ["my-command"]
#     }
#
#  LIFECYCLE EVENTS:
#     on-init              - When AutoVault starts
#     on-customer-create   - After a customer is created
#     on-customer-remove   - Before a customer is removed
#     on-template-apply    - After templates are applied
#     on-section-add       - After a section is added
#     on-backup-create     - After a backup is created
#     on-vault-switch      - When switching vaults
#
#  USAGE:
#     source bash/lib/plugins.sh
#     plugins_init
#     plugins_emit "on-customer-create" "$cust_code"
#
#===============================================================================

# Plugins directory
PLUGINS_DIR="${PLUGINS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/plugins}"

# Global plugins array
declare -gA LOADED_PLUGINS
declare -gA PLUGIN_HANDLERS

#--------------------------------------
# Initialize plugin system
# Note: Part of Plugin System API (Phase 5)
# These functions are defined for future use
# shellcheck disable=SC2034  # Public API for plugin system
#--------------------------------------
plugins_init() {
    LOADED_PLUGINS=()
    PLUGIN_HANDLERS=()
    
    # Create plugins directory if needed
    if [[ ! -d "$PLUGINS_DIR" ]]; then
        mkdir -p "$PLUGINS_DIR"
    fi
    
    # Load all plugins
    if [[ -d "$PLUGINS_DIR" ]]; then
        for plugin_dir in "$PLUGINS_DIR"/*/; do
            [[ -d "$plugin_dir" ]] || continue
            plugin_load "$(basename "$plugin_dir")"
        done
    fi
    
    # Emit init event
    plugins_emit "on-init"
}

#--------------------------------------
# Load a plugin
#--------------------------------------
plugin_load() {
    local plugin_name="$1"
    local plugin_path="$PLUGINS_DIR/$plugin_name"
    local metadata_file="$plugin_path/plugin.json"
    
    # Check plugin exists
    if [[ ! -d "$plugin_path" ]]; then
        log_debug "Plugin not found: $plugin_name"
        return 1
    fi
    
    # Check metadata exists
    if [[ ! -f "$metadata_file" ]]; then
        log_warn "Plugin missing metadata: $plugin_name"
        return 1
    fi
    
    # Parse metadata
    local plugin_version
    local plugin_enabled
    
    plugin_version=$(jq -r '.version // "1.0.0"' "$metadata_file")
    plugin_enabled=$(jq -r '.enabled // true' "$metadata_file")
    
    if [[ "$plugin_enabled" == "false" ]]; then
        log_debug "Plugin disabled: $plugin_name"
        return 0
    fi
    
    # Register plugin
    LOADED_PLUGINS["$plugin_name"]="$plugin_version"
    
    # Register event handlers
    local events
    events=$(jq -r '.events[]? // empty' "$metadata_file" 2>/dev/null) || true
    
    while IFS= read -r event; do
        [[ -z "$event" ]] && continue
        local handler_script="$plugin_path/$event.sh"
        
        if [[ -f "$handler_script" ]]; then
            # Add to handlers list for this event
            local existing="${PLUGIN_HANDLERS[$event]:-}"
            if [[ -n "$existing" ]]; then
                PLUGIN_HANDLERS["$event"]="$existing:$handler_script"
            else
                PLUGIN_HANDLERS["$event"]="$handler_script"
            fi
        fi
    done <<< "$events"
    
    # Run init script if exists
    local init_script="$plugin_path/init.sh"
    if [[ -f "$init_script" ]]; then
        source "$init_script"
    fi
    
    log_debug "Loaded plugin: $plugin_name v$plugin_version"
}

#--------------------------------------
# Emit an event to all plugins
#--------------------------------------
plugins_emit() {
    local event="$1"
    shift
    local args=("$@")
    
    local handlers="${PLUGIN_HANDLERS[$event]:-}"
    [[ -z "$handlers" ]] && return 0
    
    # Split handlers by :
    IFS=':' read -ra handler_list <<< "$handlers"
    
    for handler in "${handler_list[@]}"; do
        if [[ -f "$handler" && -x "$handler" ]]; then
            log_debug "Calling plugin handler: $handler"
            "$handler" "${args[@]}" || {
                log_warn "Plugin handler failed: $handler"
            }
        elif [[ -f "$handler" ]]; then
            log_debug "Sourcing plugin handler: $handler"
            (
                source "$handler"
                if declare -F "handle_$event" &>/dev/null; then
                    "handle_$event" "${args[@]}"
                fi
            ) || {
                log_warn "Plugin handler failed: $handler"
            }
        fi
    done
}

#--------------------------------------
# List loaded plugins
#--------------------------------------
plugins_list() {
    if [[ ${#LOADED_PLUGINS[@]} -eq 0 ]]; then
        echo "No plugins loaded"
        return 0
    fi
    
    echo "Loaded Plugins:"
    echo "---------------"
    
    for plugin_name in "${!LOADED_PLUGINS[@]}"; do
        local version="${LOADED_PLUGINS[$plugin_name]}"
        echo "  - $plugin_name v$version"
    done
}

#--------------------------------------
# Get plugin info
#--------------------------------------
plugin_info() {
    local plugin_name="$1"
    local metadata_file="$PLUGINS_DIR/$plugin_name/plugin.json"
    
    if [[ ! -f "$metadata_file" ]]; then
        echo "Plugin not found: $plugin_name"
        return 1
    fi
    
    jq '.' "$metadata_file"
}

#--------------------------------------
# Enable a plugin
#--------------------------------------
plugin_enable() {
    local plugin_name="$1"
    local metadata_file="$PLUGINS_DIR/$plugin_name/plugin.json"
    
    if [[ ! -f "$metadata_file" ]]; then
        echo "Plugin not found: $plugin_name"
        return 1
    fi
    
    local tmp_file
    tmp_file=$(mktemp)
    jq '.enabled = true' "$metadata_file" > "$tmp_file" && mv "$tmp_file" "$metadata_file"
    echo "Plugin enabled: $plugin_name"
}

#--------------------------------------
# Disable a plugin
#--------------------------------------
plugin_disable() {
    local plugin_name="$1"
    local metadata_file="$PLUGINS_DIR/$plugin_name/plugin.json"
    
    if [[ ! -f "$metadata_file" ]]; then
        echo "Plugin not found: $plugin_name"
        return 1
    fi
    
    local tmp_file
    tmp_file=$(mktemp)
    jq '.enabled = false' "$metadata_file" > "$tmp_file" && mv "$tmp_file" "$metadata_file"
    echo "Plugin disabled: $plugin_name"
    
    # Unload from memory
    unset "LOADED_PLUGINS[$plugin_name]"
}

#--------------------------------------
# Create a new plugin from template
#--------------------------------------
plugin_create() {
    local plugin_name="$1"
    local plugin_path="$PLUGINS_DIR/$plugin_name"
    
    if [[ -d "$plugin_path" ]]; then
        echo "Plugin already exists: $plugin_name"
        return 1
    fi
    
    # Create plugin structure
    mkdir -p "$plugin_path/commands"
    
    # Create metadata
    cat > "$plugin_path/plugin.json" << EOF
{
  "name": "$plugin_name",
  "version": "1.0.0",
  "description": "Description of $plugin_name",
  "author": "${USER:-Unknown}",
  "enabled": true,
  "events": [
    "on-init"
  ],
  "commands": []
}
EOF
    
    # Create init script
    cat > "$plugin_path/init.sh" << 'EOF'
#!/usr/bin/env bash
# Plugin initialization script
# This runs when the plugin is loaded

# You can define custom functions here
# plugin_my_function() {
#     echo "Hello from plugin!"
# }

EOF
    chmod +x "$plugin_path/init.sh"
    
    # Create example event handler
    cat > "$plugin_path/on-init.sh" << 'EOF'
#!/usr/bin/env bash
# Event handler for on-init event
# This runs when AutoVault initializes

handle_on_init() {
    # Your code here
    log_debug "Plugin initialized!"
}

EOF
    chmod +x "$plugin_path/on-init.sh"
    
    # Create README
    cat > "$plugin_path/README.md" << EOF
# $plugin_name

Description of your plugin.

## Installation

Copy this folder to \`~/.config/autovault/plugins/\` or the \`plugins/\` folder in AutoVault.

## Events

- \`on-init\`: Triggered when AutoVault starts

## Commands

None yet. Add commands in the \`commands/\` folder.

## Configuration

Edit \`plugin.json\` to configure the plugin.

EOF
    
    echo "Created plugin: $plugin_path"
    echo ""
    echo "Plugin structure:"
    find "$plugin_path" -type f | sed "s|$plugin_path/|  |"
}

#--------------------------------------
# Run plugin command
#--------------------------------------
plugin_run_command() {
    local plugin_name="$1"
    local command_name="$2"
    shift 2
    local args=("$@")
    
    local command_script="$PLUGINS_DIR/$plugin_name/commands/$command_name.sh"
    
    if [[ ! -f "$command_script" ]]; then
        echo "Command not found: $plugin_name:$command_name"
        return 1
    fi
    
    if [[ -x "$command_script" ]]; then
        "$command_script" "${args[@]}"
    else
        source "$command_script"
        if declare -F "cmd_$command_name" &>/dev/null; then
            "cmd_$command_name" "${args[@]}"
        elif declare -F "main" &>/dev/null; then
            main "${args[@]}"
        else
            echo "Command script missing entry point: $command_script"
            return 1
        fi
    fi
}
