#!/usr/bin/env bash
#
# install-requirements.sh
# Install required dependencies for AutoVault (Linux/macOS)
#
# Requirements:
#   - Bash 4+
#   - jq (JSON parsing)
#   - python3 (JSON generation)
#

set -euo pipefail

#--------------------------------------
# Colors and logging
#--------------------------------------
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

#--------------------------------------
# Detect package manager
#--------------------------------------
detect_package_manager() {
    if command -v apt-get &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v zypper &>/dev/null; then
        echo "zypper"
    elif command -v brew &>/dev/null; then
        echo "brew"
    elif command -v apk &>/dev/null; then
        echo "apk"
    else
        echo "unknown"
    fi
}

#--------------------------------------
# Check requirements
#--------------------------------------
check_bash_version() {
    local major_version="${BASH_VERSINFO[0]}"
    if [[ "$major_version" -ge 4 ]]; then
        log_success "Bash version $BASH_VERSION (>= 4.0 required)"
        return 0
    else
        log_error "Bash version $BASH_VERSION is too old (>= 4.0 required)"
        return 1
    fi
}

check_jq() {
    if command -v jq &>/dev/null; then
        local version
        version=$(jq --version 2>&1 || echo "unknown")
        log_success "jq is installed ($version)"
        return 0
    else
        log_warn "jq is not installed"
        return 1
    fi
}

check_python3() {
    if command -v python3 &>/dev/null; then
        local version
        version=$(python3 --version 2>&1 || echo "unknown")
        log_success "python3 is installed ($version)"
        return 0
    else
        log_warn "python3 is not installed"
        return 1
    fi
}

#--------------------------------------
# Install packages
#--------------------------------------
install_packages() {
    local pkg_manager="$1"
    shift
    local packages=("$@")

    if [[ ${#packages[@]} -eq 0 ]]; then
        log_info "No packages to install"
        return 0
    fi

    log_info "Installing packages: ${packages[*]}"

    case "$pkg_manager" in
        apt)
            log_info "Using apt-get (requires sudo)"
            sudo apt-get update
            sudo apt-get install -y "${packages[@]}"
            ;;
        dnf)
            log_info "Using dnf (requires sudo)"
            sudo dnf install -y "${packages[@]}"
            ;;
        yum)
            log_info "Using yum (requires sudo)"
            sudo yum install -y "${packages[@]}"
            ;;
        pacman)
            log_info "Using pacman (requires sudo)"
            sudo pacman -Sy --noconfirm "${packages[@]}"
            ;;
        zypper)
            log_info "Using zypper (requires sudo)"
            sudo zypper install -y "${packages[@]}"
            ;;
        brew)
            log_info "Using Homebrew"
            brew install "${packages[@]}"
            ;;
        apk)
            log_info "Using apk (requires sudo)"
            sudo apk add "${packages[@]}"
            ;;
        *)
            log_error "Unknown package manager. Please install manually: ${packages[*]}"
            return 1
            ;;
    esac
}

#--------------------------------------
# Main
#--------------------------------------
main() {
    echo "=========================================="
    echo "  AutoVault - Requirements Installer"
    echo "  (Linux / macOS)"
    echo "=========================================="
    echo

    local missing_packages=()
    local all_ok=true

    # Check Bash version
    log_info "Checking Bash version..."
    if ! check_bash_version; then
        log_error "Please upgrade Bash to version 4.0 or higher"
        all_ok=false
    fi

    echo

    # Check jq
    log_info "Checking jq..."
    if ! check_jq; then
        missing_packages+=("jq")
        all_ok=false
    fi

    echo

    # Check python3
    log_info "Checking python3..."
    if ! check_python3; then
        missing_packages+=("python3")
        all_ok=false
    fi

    echo

    # If everything is installed, we're done
    if [[ "$all_ok" == true ]]; then
        echo "=========================================="
        log_success "All requirements are already installed!"
        echo "=========================================="
        return 0
    fi

    # Detect package manager
    local pkg_manager
    pkg_manager=$(detect_package_manager)
    log_info "Detected package manager: $pkg_manager"

    if [[ "$pkg_manager" == "unknown" ]]; then
        log_error "Could not detect package manager"
        log_error "Please install the following packages manually:"
        for pkg in "${missing_packages[@]}"; do
            echo "  - $pkg"
        done
        return 1
    fi

    echo

    # Ask user for confirmation
    echo "The following packages need to be installed:"
    for pkg in "${missing_packages[@]}"; do
        echo "  - $pkg"
    done
    echo

    if [[ "$pkg_manager" != "brew" ]]; then
        log_warn "Installation requires sudo privileges."
        log_info "You will be prompted for your password."
    fi

    echo
    read -rp "Do you want to proceed with installation? [Y/n] " response
    case "$response" in
        [nN][oO]|[nN])
            log_info "Installation cancelled"
            return 1
            ;;
    esac

    echo

    # Install missing packages
    if ! install_packages "$pkg_manager" "${missing_packages[@]}"; then
        log_error "Installation failed"
        return 1
    fi

    echo
    echo "=========================================="
    log_success "Installation complete!"
    echo "=========================================="

    # Verify installation
    echo
    log_info "Verifying installation..."
    echo

    local verify_ok=true
    check_jq || verify_ok=false
    check_python3 || verify_ok=false

    if [[ "$verify_ok" == true ]]; then
        echo
        log_success "All requirements are now installed!"
    else
        echo
        log_error "Some packages failed to install. Please check the errors above."
        return 1
    fi
}

main "$@"
