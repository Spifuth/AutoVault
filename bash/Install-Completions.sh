#!/usr/bin/env bash
#===============================================================================
#
#  AUTOVAULT - Install-Completions.sh
#
#===============================================================================
#
#  DESCRIPTION:    Installs shell completion scripts for AutoVault CLI.
#                  Supports both Bash and Zsh shells with automatic detection.
#
#  COMMANDS:       install   - Install completions for current shell
#                  uninstall - Remove installed completions
#                  status    - Show current installation status
#
#  SHELLS:         bash      - Bash completion
#                  zsh       - Zsh completion
#
#  LOCATIONS:      Bash:
#                    - User: ~/.local/share/bash-completion/completions/
#                    - System: /etc/bash_completion.d/ (requires sudo)
#
#                  Zsh:
#                    - User: ~/.zsh/completions/ or ~/.local/share/zsh/completions/
#                    - Oh-My-Zsh: ~/.oh-my-zsh/completions/
#                    - System: /usr/share/zsh/site-functions/ (requires sudo)
#
#  USAGE:          Called via: ./cust-run-config.sh completions [install|uninstall|status]
#                  Direct:     bash/Install-Completions.sh [command]
#
#  OPTIONS:        --shell=bash|zsh  Force specific shell
#                  --system          Install system-wide (requires sudo)
#                  --user            Install for current user only (default)
#
#  DEPENDENCIES:   bash/lib/logging.sh
#
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPLETIONS_DIR="$PROJECT_ROOT/completions"

# Source logging
source "$SCRIPT_DIR/lib/logging.sh"

#--------------------------------------
# CONFIGURATION
#--------------------------------------

# Completion source files
BASH_COMPLETION_FILE="$COMPLETIONS_DIR/autovault.bash"
ZSH_COMPLETION_FILE="$COMPLETIONS_DIR/_autovault"

# Target filenames (main file)
BASH_TARGET_NAME="autovault"
ZSH_TARGET_NAME="_autovault"

# Additional alias names to create symlinks for (bash-completion auto-loads by command name)
BASH_ALIAS_NAMES=("cust-run-config.sh" "cust-run-config" "av" "vault" "custrun")
ZSH_ALIAS_NAMES=("_cust-run-config.sh" "_cust-run-config" "_av" "_vault" "_custrun")

# Installation locations
declare -A BASH_LOCATIONS=(
    [user]="$HOME/.local/share/bash-completion/completions"
    [system]="/etc/bash_completion.d"
)

declare -A ZSH_LOCATIONS=(
    [user]="$HOME/.zsh/completions"
    [user_local]="$HOME/.local/share/zsh/completions"
    [ohmyzsh]="$HOME/.oh-my-zsh/completions"
    [system]="/usr/share/zsh/site-functions"
)

#--------------------------------------
# DETECTION FUNCTIONS
#--------------------------------------

detect_shell() {
    # Check SHELL environment variable
    local shell_name
    shell_name=$(basename "${SHELL:-bash}")
    
    case "$shell_name" in
        bash|zsh)
            echo "$shell_name"
            ;;
        *)
            # Default to bash if unknown
            echo "bash"
            ;;
    esac
}

detect_zsh_framework() {
    # Check for Oh-My-Zsh
    if [[ -d "$HOME/.oh-my-zsh" ]]; then
        echo "ohmyzsh"
        return
    fi
    
    # Check for Prezto
    if [[ -d "$HOME/.zprezto" ]]; then
        echo "prezto"
        return
    fi
    
    # Check for Zinit
    if [[ -d "$HOME/.zinit" || -d "$HOME/.local/share/zinit" ]]; then
        echo "zinit"
        return
    fi
    
    echo "none"
}

#--------------------------------------
# STATUS FUNCTIONS
#--------------------------------------

find_installed_completions() {
    local shell="$1"
    local found=()
    
    if [[ "$shell" == "bash" ]]; then
        for loc in "${BASH_LOCATIONS[@]}"; do
            local target="$loc/$BASH_TARGET_NAME"
            if [[ -f "$target" ]]; then
                found+=("$target")
            fi
        done
    elif [[ "$shell" == "zsh" ]]; then
        for loc in "${ZSH_LOCATIONS[@]}"; do
            local target="$loc/$ZSH_TARGET_NAME"
            if [[ -f "$target" ]]; then
                found+=("$target")
            fi
        done
    fi
    
    printf '%s\n' "${found[@]}"
}

cmd_status() {
    local current_shell
    current_shell=$(detect_shell)
    local zsh_framework
    zsh_framework=$(detect_zsh_framework)
    
    echo ""
    log_info "Shell Completion Status"
    echo ""
    
    # Current shell info
    printf "  ${BOLD}Current shell:${RESET}      %s\n" "$current_shell"
    if [[ "$current_shell" == "zsh" ]]; then
        printf "  ${BOLD}Zsh framework:${RESET}      %s\n" "$zsh_framework"
    fi
    echo ""
    
    # Bash completions
    echo -e "  ${BOLD}Bash completions:${RESET}"
    local bash_found=false
    for key in "${!BASH_LOCATIONS[@]}"; do
        local loc="${BASH_LOCATIONS[$key]}"
        local target="$loc/$BASH_TARGET_NAME"
        if [[ -f "$target" ]]; then
            printf "    ${GREEN}✓${RESET} %s (%s)\n" "$target" "$key"
            bash_found=true
        fi
    done
    if [[ "$bash_found" == "false" ]]; then
        printf "    ${YELLOW}○${RESET} Not installed\n"
    fi
    echo ""
    
    # Zsh completions
    echo -e "  ${BOLD}Zsh completions:${RESET}"
    local zsh_found=false
    for key in "${!ZSH_LOCATIONS[@]}"; do
        local loc="${ZSH_LOCATIONS[$key]}"
        local target="$loc/$ZSH_TARGET_NAME"
        if [[ -f "$target" ]]; then
            printf "    ${GREEN}✓${RESET} %s (%s)\n" "$target" "$key"
            zsh_found=true
        fi
    done
    if [[ "$zsh_found" == "false" ]]; then
        printf "    ${YELLOW}○${RESET} Not installed\n"
    fi
    echo ""
    
    # Source files
    echo -e "  ${BOLD}Source files:${RESET}"
    if [[ -f "$BASH_COMPLETION_FILE" ]]; then
        printf "    ${GREEN}✓${RESET} %s\n" "$BASH_COMPLETION_FILE"
    else
        printf "    ${RED}✗${RESET} %s (missing)\n" "$BASH_COMPLETION_FILE"
    fi
    if [[ -f "$ZSH_COMPLETION_FILE" ]]; then
        printf "    ${GREEN}✓${RESET} %s\n" "$ZSH_COMPLETION_FILE"
    else
        printf "    ${RED}✗${RESET} %s (missing)\n" "$ZSH_COMPLETION_FILE"
    fi
    echo ""
}

#--------------------------------------
# INSTALL FUNCTIONS
#--------------------------------------

install_bash_completion() {
    local mode="$1"  # user or system
    local target_dir="${BASH_LOCATIONS[$mode]}"
    local target_file="$target_dir/$BASH_TARGET_NAME"
    
    if [[ ! -f "$BASH_COMPLETION_FILE" ]]; then
        log_error "Bash completion source not found: $BASH_COMPLETION_FILE"
        return 1
    fi
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY-RUN] Would install Bash completion to: $target_file"
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
    
    # Copy file
    if [[ "$mode" == "system" ]]; then
        sudo cp "$BASH_COMPLETION_FILE" "$target_file"
        sudo chmod 644 "$target_file"
    else
        cp "$BASH_COMPLETION_FILE" "$target_file"
        chmod 644 "$target_file"
    fi
    
    log_success "Bash completion installed: $target_file"
    
    # Create symlinks for alias names (bash-completion auto-loads by command name)
    for alias_name in "${BASH_ALIAS_NAMES[@]}"; do
        local alias_file="$target_dir/$alias_name"
        if [[ ! -e "$alias_file" ]]; then
            if [[ "$mode" == "system" ]]; then
                sudo ln -sf "$BASH_TARGET_NAME" "$alias_file"
            else
                ln -sf "$BASH_TARGET_NAME" "$alias_file"
            fi
            log_debug "Created symlink: $alias_file → $BASH_TARGET_NAME"
        fi
    done
    
    # Show activation hint
    echo ""
    echo -e "  ${BOLD}To activate now:${RESET}"
    echo "    source $target_file"
    echo ""
    echo -e "  ${DIM}Completions will be auto-loaded in new shells.${RESET}"
    echo -e "  ${DIM}Works with: autovault, av, vault, custrun, cust-run-config.sh${RESET}"
}

install_zsh_completion() {
    local mode="$1"  # user, user_local, ohmyzsh, or system
    local target_dir="${ZSH_LOCATIONS[$mode]}"
    local target_file="$target_dir/$ZSH_TARGET_NAME"
    
    if [[ ! -f "$ZSH_COMPLETION_FILE" ]]; then
        log_error "Zsh completion source not found: $ZSH_COMPLETION_FILE"
        return 1
    fi
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY-RUN] Would install Zsh completion to: $target_file"
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
    
    # Copy file
    if [[ "$mode" == "system" ]]; then
        sudo cp "$ZSH_COMPLETION_FILE" "$target_file"
        sudo chmod 644 "$target_file"
    else
        cp "$ZSH_COMPLETION_FILE" "$target_file"
        chmod 644 "$target_file"
    fi
    
    log_success "Zsh completion installed: $target_file"
    
    # Create symlinks for alias names
    for alias_name in "${ZSH_ALIAS_NAMES[@]}"; do
        local alias_file="$target_dir/$alias_name"
        if [[ ! -e "$alias_file" ]]; then
            if [[ "$mode" == "system" ]]; then
                sudo ln -sf "$ZSH_TARGET_NAME" "$alias_file"
            else
                ln -sf "$ZSH_TARGET_NAME" "$alias_file"
            fi
            log_debug "Created symlink: $alias_file → $ZSH_TARGET_NAME"
        fi
    done
    
    # Show activation hints based on mode
    echo ""
    if [[ "$mode" == "ohmyzsh" ]]; then
        echo -e "  ${BOLD}To activate:${RESET}"
        echo "    Restart your shell or run: omz reload"
    elif [[ "$mode" == "user" || "$mode" == "user_local" ]]; then
        echo -e "  ${BOLD}To activate:${RESET}"
        echo "    Add to your ~/.zshrc if not already present:"
        echo "      fpath=($target_dir \$fpath)"
        echo "      autoload -Uz compinit && compinit"
        echo ""
        echo "    Then restart your shell or run: exec zsh"
    else
        echo -e "  ${BOLD}To activate:${RESET}"
        echo "    Restart your shell or run: exec zsh"
    fi
    echo -e "  ${DIM}Works with: autovault, av, vault, custrun, cust-run-config.sh${RESET}"
}

cmd_install() {
    local target_shell=""
    local mode="user"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --shell=*)
                target_shell="${1#*=}"
                ;;
            --system)
                mode="system"
                ;;
            --user)
                mode="user"
                ;;
            bash|zsh)
                target_shell="$1"
                ;;
            *)
                log_warn "Unknown argument: $1"
                ;;
        esac
        shift
    done
    
    # Auto-detect shell if not specified
    if [[ -z "$target_shell" ]]; then
        target_shell=$(detect_shell)
        log_info "Detected shell: $target_shell"
    fi
    
    echo ""
    log_info "Installing completions for $target_shell ($mode mode)"
    echo ""
    
    case "$target_shell" in
        bash)
            install_bash_completion "$mode"
            ;;
        zsh)
            # For zsh user mode, check for Oh-My-Zsh first
            if [[ "$mode" == "user" ]]; then
                local zsh_framework
                zsh_framework=$(detect_zsh_framework)
                if [[ "$zsh_framework" == "ohmyzsh" ]]; then
                    log_info "Detected Oh-My-Zsh, installing to completions folder"
                    install_zsh_completion "ohmyzsh"
                else
                    install_zsh_completion "user"
                fi
            else
                install_zsh_completion "$mode"
            fi
            ;;
        all)
            log_info "Installing for all shells..."
            install_bash_completion "$mode" || true
            echo ""
            if [[ "$mode" == "user" ]]; then
                local zsh_framework
                zsh_framework=$(detect_zsh_framework)
                if [[ "$zsh_framework" == "ohmyzsh" ]]; then
                    install_zsh_completion "ohmyzsh" || true
                else
                    install_zsh_completion "user" || true
                fi
            else
                install_zsh_completion "$mode" || true
            fi
            ;;
        *)
            log_error "Unsupported shell: $target_shell"
            log_info "Supported shells: bash, zsh, all"
            return 1
            ;;
    esac
}

#--------------------------------------
# UNINSTALL FUNCTIONS
#--------------------------------------

cmd_uninstall() {
    local target_shell=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --shell=*)
                target_shell="${1#*=}"
                ;;
            bash|zsh|all)
                target_shell="$1"
                ;;
            *)
                log_warn "Unknown argument: $1"
                ;;
        esac
        shift
    done
    
    # Auto-detect shell if not specified
    if [[ -z "$target_shell" ]]; then
        target_shell="all"
    fi
    
    echo ""
    log_info "Uninstalling completions..."
    echo ""
    
    local removed=0
    
    # Remove bash completions
    if [[ "$target_shell" == "bash" || "$target_shell" == "all" ]]; then
        for key in "${!BASH_LOCATIONS[@]}"; do
            local loc="${BASH_LOCATIONS[$key]}"
            local target="$loc/$BASH_TARGET_NAME"
            if [[ -f "$target" ]]; then
                if [[ "${DRY_RUN:-false}" == "true" ]]; then
                    log_info "[DRY-RUN] Would remove: $target"
                else
                    if [[ "$key" == "system" ]]; then
                        sudo rm -f "$target"
                    else
                        rm -f "$target"
                    fi
                    log_success "Removed: $target"
                fi
                ((removed++))
            fi
        done
    fi
    
    # Remove zsh completions
    if [[ "$target_shell" == "zsh" || "$target_shell" == "all" ]]; then
        for key in "${!ZSH_LOCATIONS[@]}"; do
            local loc="${ZSH_LOCATIONS[$key]}"
            local target="$loc/$ZSH_TARGET_NAME"
            if [[ -f "$target" ]]; then
                if [[ "${DRY_RUN:-false}" == "true" ]]; then
                    log_info "[DRY-RUN] Would remove: $target"
                else
                    if [[ "$key" == "system" ]]; then
                        sudo rm -f "$target"
                    else
                        rm -f "$target"
                    fi
                    log_success "Removed: $target"
                fi
                ((removed++))
            fi
        done
    fi
    
    if [[ "$removed" -eq 0 ]]; then
        log_info "No completions found to remove"
    fi
}

#--------------------------------------
# HELP
#--------------------------------------

show_help() {
    cat << 'EOF'
AutoVault Shell Completions

USAGE:
    cust-run-config.sh completions <command> [options]

COMMANDS:
    install     Install shell completions
    uninstall   Remove installed completions
    status      Show installation status

OPTIONS:
    --shell=<shell>   Target shell (bash, zsh, or all)
    --system          Install system-wide (requires sudo)
    --user            Install for current user only (default)

EXAMPLES:
    # Install for current shell (auto-detected)
    cust-run-config.sh completions install

    # Install for specific shell
    cust-run-config.sh completions install bash
    cust-run-config.sh completions install zsh

    # Install system-wide
    cust-run-config.sh completions install --system

    # Check status
    cust-run-config.sh completions status

    # Uninstall all
    cust-run-config.sh completions uninstall
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
