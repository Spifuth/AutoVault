#!/usr/bin/env bash
#===============================================================================
#
#  AUTOVAULT INSTALLER
#
#===============================================================================
#
#  DESCRIPTION:    Universal installer for AutoVault
#                  Works on Linux (Debian, Ubuntu, Arch, Fedora) and macOS
#
#  USAGE:          curl -fsSL https://raw.githubusercontent.com/Spifuth/AutoVault/main/install.sh | bash
#                  wget -qO- https://raw.githubusercontent.com/Spifuth/AutoVault/main/install.sh | bash
#
#  OPTIONS:        --prefix <path>    Install to custom location (default: /usr/local)
#                  --user             Install to ~/.local (no sudo required)
#                  --version <ver>    Install specific version (default: latest)
#                  --uninstall        Remove AutoVault
#                  --help             Show this help
#
#===============================================================================

set -euo pipefail

# Configuration
REPO_OWNER="Spifuth"
REPO_NAME="AutoVault"
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local}"
INSTALL_VERSION="${INSTALL_VERSION:-latest}"
USER_INSTALL=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}ℹ${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*" >&2; }

# Print banner
print_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
    ___         __       _    __            ____
   /   | __  __/ /_____ | |  / /___ ___  __/ / /_
  / /| |/ / / / __/ __ \| | / / __ `/ / / / / __/
 / ___ / /_/ / /_/ /_/ /| |/ / /_/ / /_/ / / /_
/_/  |_\__,_/\__/\____/ |___/\__,_/\__,_/_/\__/

EOF
    echo -e "${NC}"
    echo -e "  ${YELLOW}Universal Installer${NC}"
    echo
}

# Check for required commands
check_dependencies() {
    local missing=()
    
    for cmd in curl tar jq; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing[*]}"
        echo
        echo "Install them with:"
        
        if [[ -f /etc/debian_version ]]; then
            echo "  sudo apt-get install ${missing[*]}"
        elif [[ -f /etc/arch-release ]]; then
            echo "  sudo pacman -S ${missing[*]}"
        elif [[ -f /etc/fedora-release ]] || [[ -f /etc/redhat-release ]]; then
            echo "  sudo dnf install ${missing[*]}"
        elif [[ "$(uname)" == "Darwin" ]]; then
            echo "  brew install ${missing[*]}"
        fi
        
        exit 1
    fi
}

# Detect OS and architecture
detect_system() {
    OS="$(uname -s)"
    ARCH="$(uname -m)"
    
    case "$OS" in
        Linux)  OS="linux" ;;
        Darwin) OS="darwin" ;;
        *)      log_error "Unsupported OS: $OS"; exit 1 ;;
    esac
    
    case "$ARCH" in
        x86_64|amd64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        armv7l) ARCH="arm" ;;
        *)      log_error "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    
    log_info "Detected: $OS ($ARCH)"
}

# Get latest version from GitHub
get_latest_version() {
    if [[ "$INSTALL_VERSION" == "latest" ]]; then
        log_info "Fetching latest version..."
        INSTALL_VERSION=$(curl -fsSL "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest" | \
            jq -r '.tag_name' 2>/dev/null || echo "")
        
        if [[ -z "$INSTALL_VERSION" || "$INSTALL_VERSION" == "null" ]]; then
            # No releases yet, use main branch
            log_warning "No releases found, using main branch"
            INSTALL_VERSION="main"
        fi
    fi
    
    log_info "Version: $INSTALL_VERSION"
}

# Download and extract
download_and_extract() {
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap "rm -rf $tmp_dir" EXIT
    
    log_info "Downloading AutoVault..."
    
    local download_url
    if [[ "$INSTALL_VERSION" == "main" || "$INSTALL_VERSION" == "dev" ]]; then
        # Download from branch
        download_url="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/heads/${INSTALL_VERSION}.tar.gz"
    else
        # Download from release
        download_url="https://github.com/${REPO_OWNER}/${REPO_NAME}/releases/download/${INSTALL_VERSION}/autovault-${INSTALL_VERSION}.tar.gz"
        
        # Fallback to archive if release asset doesn't exist
        if ! curl -fsSL --head "$download_url" &>/dev/null; then
            download_url="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/tags/${INSTALL_VERSION}.tar.gz"
        fi
    fi
    
    if ! curl -fsSL "$download_url" -o "$tmp_dir/autovault.tar.gz"; then
        log_error "Failed to download from: $download_url"
        exit 1
    fi
    
    log_info "Extracting..."
    tar -xzf "$tmp_dir/autovault.tar.gz" -C "$tmp_dir"
    
    # Find extracted directory
    EXTRACTED_DIR=$(find "$tmp_dir" -maxdepth 1 -type d -name "AutoVault*" | head -1)
    if [[ -z "$EXTRACTED_DIR" ]]; then
        EXTRACTED_DIR=$(find "$tmp_dir" -maxdepth 1 -type d -name "autovault*" | head -1)
    fi
    
    if [[ -z "$EXTRACTED_DIR" ]]; then
        log_error "Failed to find extracted directory"
        exit 1
    fi
    
    # Install files
    install_files "$EXTRACTED_DIR"
}

# Install files to destination
install_files() {
    local src_dir="$1"
    local bin_dir="$INSTALL_PREFIX/bin"
    local lib_dir="$INSTALL_PREFIX/lib/autovault"
    local share_dir="$INSTALL_PREFIX/share/autovault"
    local completion_dir
    
    # Determine completion directory
    if [[ "$USER_INSTALL" == "true" ]]; then
        completion_dir="$HOME/.local/share/bash-completion/completions"
    else
        if [[ -d /etc/bash_completion.d ]]; then
            completion_dir="/etc/bash_completion.d"
        else
            completion_dir="$INSTALL_PREFIX/share/bash-completion/completions"
        fi
    fi
    
    log_info "Installing to $INSTALL_PREFIX..."
    
    # Create directories
    local sudo_cmd=""
    if [[ "$USER_INSTALL" != "true" ]] && [[ ! -w "$INSTALL_PREFIX" ]]; then
        sudo_cmd="sudo"
        log_info "Sudo required for installation"
    fi
    
    $sudo_cmd mkdir -p "$bin_dir" "$lib_dir" "$share_dir"
    
    # Install main script
    $sudo_cmd cp "$src_dir/cust-run-config.sh" "$bin_dir/autovault"
    $sudo_cmd chmod +x "$bin_dir/autovault"
    
    # Install bash scripts
    $sudo_cmd cp -r "$src_dir/bash" "$lib_dir/"
    $sudo_cmd chmod +x "$lib_dir/bash"/*.sh
    $sudo_cmd chmod +x "$lib_dir/bash/lib"/*.sh 2>/dev/null || true
    
    # Install config templates
    if [[ -d "$src_dir/config" ]]; then
        $sudo_cmd cp -r "$src_dir/config" "$share_dir/"
    fi
    
    # Install hooks examples
    if [[ -d "$src_dir/hooks" ]]; then
        $sudo_cmd cp -r "$src_dir/hooks" "$share_dir/"
    fi
    
    # Install completions
    if [[ -f "$src_dir/completions/autovault.bash" ]]; then
        $sudo_cmd mkdir -p "$completion_dir"
        $sudo_cmd cp "$src_dir/completions/autovault.bash" "$completion_dir/autovault"
    fi
    
    # Install zsh completions
    if [[ -f "$src_dir/completions/_autovault" ]]; then
        local zsh_completion_dir
        if [[ "$USER_INSTALL" == "true" ]]; then
            zsh_completion_dir="$HOME/.local/share/zsh/site-functions"
        else
            zsh_completion_dir="$INSTALL_PREFIX/share/zsh/site-functions"
        fi
        $sudo_cmd mkdir -p "$zsh_completion_dir"
        $sudo_cmd cp "$src_dir/completions/_autovault" "$zsh_completion_dir/"
    fi
    
    # Update script paths
    $sudo_cmd sed -i.bak "s|SCRIPT_DIR=.*|SCRIPT_DIR=\"$lib_dir\"|" "$bin_dir/autovault" 2>/dev/null || \
        $sudo_cmd sed -i '' "s|SCRIPT_DIR=.*|SCRIPT_DIR=\"$lib_dir\"|" "$bin_dir/autovault"
    $sudo_cmd rm -f "$bin_dir/autovault.bak"
    
    log_success "AutoVault installed successfully!"
}

# Uninstall AutoVault
uninstall() {
    log_info "Uninstalling AutoVault..."
    
    local bin_dir="$INSTALL_PREFIX/bin"
    local lib_dir="$INSTALL_PREFIX/lib/autovault"
    local share_dir="$INSTALL_PREFIX/share/autovault"
    
    local sudo_cmd=""
    if [[ "$USER_INSTALL" != "true" ]] && [[ ! -w "$INSTALL_PREFIX" ]]; then
        sudo_cmd="sudo"
    fi
    
    $sudo_cmd rm -f "$bin_dir/autovault"
    $sudo_cmd rm -rf "$lib_dir"
    $sudo_cmd rm -rf "$share_dir"
    $sudo_cmd rm -f "/etc/bash_completion.d/autovault" 2>/dev/null || true
    $sudo_cmd rm -f "$INSTALL_PREFIX/share/bash-completion/completions/autovault" 2>/dev/null || true
    $sudo_cmd rm -f "$INSTALL_PREFIX/share/zsh/site-functions/_autovault" 2>/dev/null || true
    
    log_success "AutoVault uninstalled successfully!"
}

# Post-install instructions
post_install() {
    echo
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Installation complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    
    if [[ "$USER_INSTALL" == "true" ]]; then
        echo "Add to your PATH if not already:"
        echo -e "  ${CYAN}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
        echo
    fi
    
    echo "Get started:"
    echo -e "  ${CYAN}autovault --help${NC}         Show available commands"
    echo -e "  ${CYAN}autovault init${NC}           Initialize a new vault"
    echo -e "  ${CYAN}autovault doctor${NC}         Check your setup"
    echo
    echo "Documentation:"
    echo -e "  ${CYAN}https://github.com/${REPO_OWNER}/${REPO_NAME}/wiki${NC}"
    echo
}

# Show help
show_help() {
    cat << EOF
AutoVault Installer

USAGE:
    install.sh [OPTIONS]

OPTIONS:
    --prefix <path>    Install to custom location (default: /usr/local)
    --user             Install to ~/.local (no sudo required)
    --version <ver>    Install specific version (default: latest)
    --uninstall        Remove AutoVault
    -h, --help         Show this help

EXAMPLES:
    # Install latest version system-wide
    ./install.sh

    # Install to home directory (no sudo)
    ./install.sh --user

    # Install specific version
    ./install.sh --version v2.4.0

    # Install to custom location
    ./install.sh --prefix /opt/autovault

    # Uninstall
    ./install.sh --uninstall

ONE-LINE INSTALL:
    curl -fsSL https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/install.sh | bash
    curl -fsSL https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main/install.sh | bash -s -- --user

EOF
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --prefix)
                INSTALL_PREFIX="$2"
                shift 2
                ;;
            --user)
                USER_INSTALL=true
                INSTALL_PREFIX="$HOME/.local"
                shift
                ;;
            --version)
                INSTALL_VERSION="$2"
                shift 2
                ;;
            --uninstall)
                print_banner
                uninstall
                exit 0
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Main
main() {
    parse_args "$@"
    print_banner
    check_dependencies
    detect_system
    get_latest_version
    download_and_extract
    post_install
}

main "$@"
