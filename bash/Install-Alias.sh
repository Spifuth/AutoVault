#!/usr/bin/env bash
#===============================================================================
#
#  AUTOVAULT - Install-Alias.sh
#
#===============================================================================
#
#  DESCRIPTION:    Creates a system alias or symlink for AutoVault CLI.
#                  Allows users to run AutoVault from anywhere with a custom
#                  command name (e.g., 'autovault', 'av', 'vault').
#
#  COMMANDS:       install   - Create alias/symlink
#                  uninstall - Remove alias/symlink
#                  status    - Show current installation status
#
#  METHODS:        symlink   - Create symlink in /usr/local/bin (recommended)
#                  alias     - Add alias to shell rc file (.bashrc/.zshrc)
#                  path      - Add AutoVault directory to PATH
#
#  USAGE:          Called via: ./cust-run-config.sh alias [install|uninstall|status]
#                  Direct:     bash/Install-Alias.sh [command]
#
#  OPTIONS:        --name=<alias>    Custom alias name (default: autovault)
#                  --method=<method> Installation method (symlink/alias/path)
#                  --system          Install system-wide (requires sudo)
#
#  DEPENDENCIES:   bash/lib/logging.sh
#
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MAIN_SCRIPT="$PROJECT_ROOT/cust-run-config.sh"

# Source logging
source "$SCRIPT_DIR/lib/logging.sh"

#--------------------------------------
# CONFIGURATION
#--------------------------------------

# Default alias name
DEFAULT_ALIAS_NAME="autovault"

# Installation locations
SYMLINK_USER_DIR="$HOME/.local/bin"
SYMLINK_SYSTEM_DIR="/usr/local/bin"

# Shell RC files
declare -A SHELL_RC_FILES=(
    [bash]="$HOME/.bashrc"
    [zsh]="$HOME/.zshrc"
)

#--------------------------------------
# DETECTION FUNCTIONS
#--------------------------------------

detect_shell() {
    local shell_name
    shell_name=$(basename "${SHELL:-bash}")
    
    case "$shell_name" in
        bash|zsh)
            echo "$shell_name"
            ;;
        *)
            echo "bash"
            ;;
    esac
}

get_rc_file() {
    local shell="$1"
    echo "${SHELL_RC_FILES[$shell]:-$HOME/.bashrc}"
}

is_in_path() {
    local dir="$1"
    [[ ":$PATH:" == *":$dir:"* ]]
}

#--------------------------------------
# STATUS FUNCTIONS
#--------------------------------------

find_existing_aliases() {
    local found=()
    
    # Check symlinks in common locations
    for dir in "$SYMLINK_USER_DIR" "$SYMLINK_SYSTEM_DIR"; do
        if [[ -d "$dir" ]]; then
            while IFS= read -r -d '' link; do
                local target
                target=$(readlink -f "$link" 2>/dev/null || true)
                if [[ "$target" == "$MAIN_SCRIPT" ]]; then
                    found+=("symlink:$link")
                fi
            done < <(find "$dir" -maxdepth 1 -type l -print0 2>/dev/null)
        fi
    done
    
    # Check shell aliases in rc files
    for shell in bash zsh; do
        local rc_file="${SHELL_RC_FILES[$shell]}"
        if [[ -f "$rc_file" ]]; then
            while IFS= read -r line; do
                if [[ "$line" =~ ^alias[[:space:]]+([a-zA-Z0-9_-]+)=.*cust-run-config\.sh ]]; then
                    found+=("alias:${BASH_REMATCH[1]}:$rc_file")
                fi
            done < "$rc_file"
        fi
    done
    
    printf '%s\n' "${found[@]}"
}

cmd_status() {
    local current_shell
    current_shell=$(detect_shell)
    
    echo ""
    log_info "AutoVault Alias Status"
    echo ""
    
    # Main script location
    printf "  ${BOLD}Script location:${RESET}    %s\n" "$MAIN_SCRIPT"
    printf "  ${BOLD}Current shell:${RESET}      %s\n" "$current_shell"
    echo ""
    
    # Check PATH directories
    echo -e "  ${BOLD}PATH directories:${RESET}"
    if is_in_path "$SYMLINK_USER_DIR"; then
        printf "    ${GREEN}✓${RESET} %s (in PATH)\n" "$SYMLINK_USER_DIR"
    else
        printf "    ${YELLOW}○${RESET} %s (not in PATH)\n" "$SYMLINK_USER_DIR"
    fi
    if is_in_path "$SYMLINK_SYSTEM_DIR"; then
        printf "    ${GREEN}✓${RESET} %s (in PATH)\n" "$SYMLINK_SYSTEM_DIR"
    else
        printf "    ${YELLOW}○${RESET} %s (not in PATH)\n" "$SYMLINK_SYSTEM_DIR"
    fi
    echo ""
    
    # Find existing installations
    echo -e "  ${BOLD}Installed aliases:${RESET}"
    local found_any=false
    
    while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        found_any=true
        
        local type="${entry%%:*}"
        local rest="${entry#*:}"
        
        case "$type" in
            symlink)
                local name
                name=$(basename "$rest")
                printf "    ${GREEN}✓${RESET} %s → symlink (%s)\n" "$name" "$rest"
                ;;
            alias)
                local name="${rest%%:*}"
                local file="${rest#*:}"
                printf "    ${GREEN}✓${RESET} %s → shell alias (%s)\n" "$name" "$file"
                ;;
        esac
    done < <(find_existing_aliases)
    
    if [[ "$found_any" == "false" ]]; then
        printf "    ${YELLOW}○${RESET} No aliases installed\n"
    fi
    echo ""
    
    # Suggestions
    echo -e "  ${BOLD}Quick install:${RESET}"
    echo "    ./cust-run-config.sh alias install"
    echo "    ./cust-run-config.sh alias install --name=av"
    echo ""
}

#--------------------------------------
# INSTALL FUNCTIONS
#--------------------------------------

install_symlink() {
    local name="$1"
    local mode="$2"  # user or system
    local target_dir
    
    if [[ "$mode" == "system" ]]; then
        target_dir="$SYMLINK_SYSTEM_DIR"
    else
        target_dir="$SYMLINK_USER_DIR"
    fi
    
    local target_path="$target_dir/$name"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY-RUN] Would create symlink: $target_path → $MAIN_SCRIPT"
        return 0
    fi
    
    # Create directory if needed
    if [[ ! -d "$target_dir" ]]; then
        if [[ "$mode" == "system" ]]; then
            sudo mkdir -p "$target_dir"
        else
            mkdir -p "$target_dir"
        fi
        log_debug "Created directory: $target_dir"
    fi
    
    # Check if something already exists
    if [[ -e "$target_path" ]]; then
        if [[ -L "$target_path" ]]; then
            local existing_target
            existing_target=$(readlink -f "$target_path")
            if [[ "$existing_target" == "$MAIN_SCRIPT" ]]; then
                log_info "Symlink already exists: $target_path"
                return 0
            else
                log_warn "Symlink exists but points elsewhere: $existing_target"
                log_warn "Removing old symlink..."
                if [[ "$mode" == "system" ]]; then
                    sudo rm "$target_path"
                else
                    rm "$target_path"
                fi
            fi
        else
            log_error "File already exists (not a symlink): $target_path"
            return 1
        fi
    fi
    
    # Create symlink
    if [[ "$mode" == "system" ]]; then
        sudo ln -s "$MAIN_SCRIPT" "$target_path"
    else
        ln -s "$MAIN_SCRIPT" "$target_path"
    fi
    
    log_success "Symlink created: $target_path → $MAIN_SCRIPT"
    
    # Check if directory is in PATH
    if ! is_in_path "$target_dir"; then
        echo ""
        log_warn "$target_dir is not in your PATH"
        echo ""
        echo -e "  ${BOLD}Add to your shell rc file:${RESET}"
        echo "    export PATH=\"$target_dir:\$PATH\""
        echo ""
        echo -e "  ${BOLD}Or run:${RESET}"
        echo "    echo 'export PATH=\"$target_dir:\$PATH\"' >> $(get_rc_file "$(detect_shell)")"
    else
        echo ""
        echo -e "  ${BOLD}You can now run:${RESET}"
        echo "    $name --help"
        echo "    $name status"
    fi
}

install_shell_alias() {
    local name="$1"
    local shell
    shell=$(detect_shell)
    local rc_file
    rc_file=$(get_rc_file "$shell")
    
    local alias_line="alias $name='$MAIN_SCRIPT'"
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY-RUN] Would add to $rc_file:"
        log_info "  $alias_line"
        return 0
    fi
    
    # Check if alias already exists
    if grep -q "^alias $name=" "$rc_file" 2>/dev/null; then
        log_info "Alias '$name' already exists in $rc_file"
        
        # Check if it points to the right script
        if grep -q "^alias $name=.*cust-run-config.sh" "$rc_file"; then
            log_info "Alias already configured correctly"
            return 0
        else
            log_warn "Alias exists but points elsewhere. Please update manually."
            return 1
        fi
    fi
    
    # Add alias to rc file
    echo "" >> "$rc_file"
    echo "# AutoVault alias (added $(date +%Y-%m-%d))" >> "$rc_file"
    echo "$alias_line" >> "$rc_file"
    
    log_success "Alias added to $rc_file"
    echo ""
    echo -e "  ${BOLD}To activate now:${RESET}"
    echo "    source $rc_file"
    echo ""
    echo -e "  ${BOLD}Or start a new shell, then run:${RESET}"
    echo "    $name --help"
}

cmd_install() {
    local alias_name="$DEFAULT_ALIAS_NAME"
    local method="symlink"
    local mode="user"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                export DRY_RUN
                ;;
            --name=*)
                alias_name="${1#*=}"
                ;;
            --method=*)
                method="${1#*=}"
                ;;
            --system)
                mode="system"
                ;;
            --user)
                mode="user"
                ;;
            symlink|alias|path)
                method="$1"
                ;;
            *)
                # Check if it's a simple name argument
                if [[ ! "$1" =~ ^- ]]; then
                    alias_name="$1"
                else
                    log_warn "Unknown argument: $1"
                fi
                ;;
        esac
        shift
    done
    
    # Validate alias name
    if [[ ! "$alias_name" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
        log_error "Invalid alias name: $alias_name"
        log_info "Alias must start with a letter and contain only letters, numbers, underscores, and hyphens"
        return 1
    fi
    
    echo ""
    log_info "Installing alias '$alias_name' (method: $method, mode: $mode)"
    echo ""
    
    case "$method" in
        symlink)
            install_symlink "$alias_name" "$mode"
            ;;
        alias)
            install_shell_alias "$alias_name"
            ;;
        path)
            log_info "To add AutoVault to your PATH, add this to your shell rc file:"
            echo ""
            echo "    export PATH=\"$PROJECT_ROOT:\$PATH\""
            echo ""
            echo "  Then create a symlink to the script:"
            echo "    ln -s $MAIN_SCRIPT $PROJECT_ROOT/$alias_name"
            ;;
        *)
            log_error "Unknown method: $method"
            log_info "Supported methods: symlink, alias, path"
            return 1
            ;;
    esac
}

#--------------------------------------
# UNINSTALL FUNCTIONS
#--------------------------------------

cmd_uninstall() {
    local alias_name=""
    local remove_all=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                export DRY_RUN
                ;;
            --all)
                remove_all=true
                ;;
            --name=*)
                alias_name="${1#*=}"
                ;;
            *)
                if [[ ! "$1" =~ ^- ]]; then
                    alias_name="$1"
                fi
                ;;
        esac
        shift
    done
    
    echo ""
    log_info "Removing AutoVault aliases..."
    echo ""
    
    local removed=0
    
    while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        
        local type="${entry%%:*}"
        local rest="${entry#*:}"
        
        case "$type" in
            symlink)
                local name
                name=$(basename "$rest")
                
                # Skip if specific name requested and doesn't match
                if [[ -n "$alias_name" && "$name" != "$alias_name" ]]; then
                    continue
                fi
                
                if [[ "${DRY_RUN:-false}" == "true" ]]; then
                    log_info "[DRY-RUN] Would remove symlink: $rest"
                else
                    if [[ -w "$(dirname "$rest")" ]]; then
                        rm "$rest"
                    else
                        sudo rm "$rest"
                    fi
                    log_success "Removed symlink: $rest"
                fi
                ((removed++))
                ;;
            alias)
                local name="${rest%%:*}"
                local file="${rest#*:}"
                
                # Skip if specific name requested and doesn't match
                if [[ -n "$alias_name" && "$name" != "$alias_name" ]]; then
                    continue
                fi
                
                if [[ "${DRY_RUN:-false}" == "true" ]]; then
                    log_info "[DRY-RUN] Would remove alias '$name' from $file"
                else
                    # Remove the alias line and comment above it
                    local tmp_file
                    tmp_file=$(mktemp)
                    grep -v "^alias $name=\|^# AutoVault alias" "$file" > "$tmp_file"
                    mv "$tmp_file" "$file"
                    log_success "Removed alias '$name' from $file"
                fi
                ((removed++))
                ;;
        esac
    done < <(find_existing_aliases)
    
    if [[ "$removed" -eq 0 ]]; then
        log_info "No aliases found to remove"
    fi
}

#--------------------------------------
# HELP
#--------------------------------------

show_help() {
    cat << 'EOF'
AutoVault System Alias

USAGE:
    cust-run-config.sh alias <command> [options]

COMMANDS:
    install     Create system alias or symlink
    uninstall   Remove installed alias
    status      Show current installation status

OPTIONS:
    --name=<alias>      Custom alias name (default: autovault)
    --method=<method>   Installation method:
                          symlink - Symlink in PATH (recommended)
                          alias   - Shell alias in rc file
    --system            Install system-wide (requires sudo)
    --user              Install for current user only (default)

EXAMPLES:
    # Install with default name (autovault)
    cust-run-config.sh alias install

    # Install with custom name
    cust-run-config.sh alias install --name=av
    cust-run-config.sh alias install vault

    # Install as shell alias instead of symlink
    cust-run-config.sh alias install --method=alias

    # System-wide installation
    cust-run-config.sh alias install --system

    # Check status
    cust-run-config.sh alias status

    # Remove specific alias
    cust-run-config.sh alias uninstall autovault

    # Remove all aliases
    cust-run-config.sh alias uninstall --all

ALIAS SUGGESTIONS:
    autovault   Full name (default)
    av          Short and quick
    vault       If you don't use Hashicorp Vault
    custrun     Descriptive
EOF
}

#--------------------------------------
# MAIN
#--------------------------------------

main() {
    local cmd="${1:-status}"
    shift || true
    
    case "$cmd" in
        install)
            cmd_install "$@"
            ;;
        uninstall|remove)
            cmd_uninstall "$@"
            ;;
        status|check)
            cmd_status
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $cmd"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
