#!/usr/bin/env bash
#
# Install-Requirements.sh - Dependency management for AutoVault
#
# Usage: Called from cust-run-config.sh
#   bash/Install-Requirements.sh check
#   bash/Install-Requirements.sh install
#
# Depends on: bash/lib/logging.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging (config.sh depends on these tools, so we can't source it yet)
source "$SCRIPT_DIR/lib/logging.sh"

#--------------------------------------
# REQUIRED DEPENDENCIES
#--------------------------------------
declare -A REQUIREMENTS=(
  [jq]="JSON processor - required for config parsing"
  [python3]="Python 3 - required for JSON generation"
)

# Optional dependencies
declare -A OPTIONAL=(
  [git]="Git - for version control"
)

#--------------------------------------
# CHECK FUNCTIONS
#--------------------------------------

check_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1
}

get_version() {
  local cmd="$1"
  case "$cmd" in
    jq)
      jq --version 2>/dev/null | head -1
      ;;
    python3)
      python3 --version 2>/dev/null | head -1
      ;;
    git)
      git --version 2>/dev/null | head -1
      ;;
    *)
      echo "installed"
      ;;
  esac
}

#--------------------------------------
# CHECK REQUIREMENTS
#--------------------------------------
check_requirements() {
  local verbose="${VERBOSE:-false}"
  local missing=0
  local optional_missing=0

  echo ""
  log_info "Checking required dependencies..."
  echo ""

  for cmd in "${!REQUIREMENTS[@]}"; do
    local desc="${REQUIREMENTS[$cmd]}"
    
    if check_command "$cmd"; then
      local version
      version="$(get_version "$cmd")"
      printf "  ${GREEN}✓${RESET} %-12s %s\n" "$cmd" "$version"
      if [[ "$verbose" == "true" ]]; then
        printf "    %s\n" "$desc"
      fi
    else
      printf "  ${RED}✗${RESET} %-12s not found\n" "$cmd"
      printf "    %s\n" "$desc"
      ((missing++))
    fi
  done

  if [[ "$verbose" == "true" ]] && [[ ${#OPTIONAL[@]} -gt 0 ]]; then
    echo ""
    log_info "Checking optional dependencies..."
    echo ""
    
    for cmd in "${!OPTIONAL[@]}"; do
      local desc="${OPTIONAL[$cmd]}"
      
      if check_command "$cmd"; then
        local version
        version="$(get_version "$cmd")"
        printf "  ${GREEN}✓${RESET} %-12s %s\n" "$cmd" "$version"
      else
        printf "  ${YELLOW}?${RESET} %-12s not found (optional)\n" "$cmd"
        printf "    %s\n" "$desc"
        ((optional_missing++))
      fi
    done
  fi

  echo ""
  
  if [[ $missing -gt 0 ]]; then
    log_error "$missing required dependency(ies) missing"
    log_info "Run 'install-requirements.sh' to install missing dependencies"
    return 1
  fi

  log_success "All required dependencies are installed"
  
  if [[ $optional_missing -gt 0 ]]; then
    log_info "$optional_missing optional dependency(ies) not installed"
  fi

  return 0
}

#--------------------------------------
# INSTALL FUNCTIONS
#--------------------------------------

detect_package_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    echo "apt"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif command -v yum >/dev/null 2>&1; then
    echo "yum"
  elif command -v pacman >/dev/null 2>&1; then
    echo "pacman"
  elif command -v brew >/dev/null 2>&1; then
    echo "brew"
  elif command -v apk >/dev/null 2>&1; then
    echo "apk"
  else
    echo "unknown"
  fi
}

install_package() {
  local pkg="$1"
  local pm
  pm="$(detect_package_manager)"

  case "$pm" in
    apt)
      sudo apt-get update && sudo apt-get install -y "$pkg"
      ;;
    dnf)
      sudo dnf install -y "$pkg"
      ;;
    yum)
      sudo yum install -y "$pkg"
      ;;
    pacman)
      sudo pacman -S --noconfirm "$pkg"
      ;;
    brew)
      brew install "$pkg"
      ;;
    apk)
      sudo apk add "$pkg"
      ;;
    *)
      log_error "Unknown package manager. Please install $pkg manually."
      return 1
      ;;
  esac
}

install_requirements() {
  local dry_run="${DRY_RUN:-false}"
  local pm
  pm="$(detect_package_manager)"
  
  echo ""
  log_info "Detected package manager: $pm"
  echo ""

  if [[ "$pm" == "unknown" ]]; then
    log_error "Could not detect package manager"
    log_info "Please install the following packages manually:"
    for cmd in "${!REQUIREMENTS[@]}"; do
      printf "  - %s\n" "$cmd"
    done
    return 1
  fi

  local to_install=()
  
  for cmd in "${!REQUIREMENTS[@]}"; do
    if ! check_command "$cmd"; then
      to_install+=("$cmd")
    fi
  done

  if [[ ${#to_install[@]} -eq 0 ]]; then
    log_success "All required dependencies are already installed"
    return 0
  fi

  log_info "The following packages will be installed:"
  for pkg in "${to_install[@]}"; do
    printf "  - %s\n" "$pkg"
  done
  echo ""

  if [[ "$dry_run" == "true" ]]; then
    log_info "[DRY RUN] Would install: ${to_install[*]}"
    return 0
  fi

  read -rp "Continue with installation? [y/N]: " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    log_info "Installation cancelled"
    return 0
  fi

  local failed=0
  for pkg in "${to_install[@]}"; do
    log_info "Installing $pkg..."
    if install_package "$pkg"; then
      log_success "Installed $pkg"
    else
      log_error "Failed to install $pkg"
      ((failed++))
    fi
  done

  echo ""
  
  if [[ $failed -gt 0 ]]; then
    log_error "$failed package(s) failed to install"
    return 1
  fi

  log_success "All dependencies installed successfully"
  return 0
}

#--------------------------------------
# SHOW INSTALL INSTRUCTIONS
#--------------------------------------
show_install_instructions() {
  local pm
  pm="$(detect_package_manager)"

  echo ""
  log_info "Installation instructions for missing dependencies:"
  echo ""

  case "$pm" in
    apt)
      echo "  sudo apt-get update"
      echo "  sudo apt-get install -y jq python3"
      ;;
    dnf)
      echo "  sudo dnf install -y jq python3"
      ;;
    yum)
      echo "  sudo yum install -y jq python3"
      ;;
    pacman)
      echo "  sudo pacman -S jq python"
      ;;
    brew)
      echo "  brew install jq python3"
      ;;
    apk)
      echo "  sudo apk add jq python3"
      ;;
    *)
      echo "  Please install 'jq' and 'python3' using your system's package manager"
      ;;
  esac

  echo ""
}

#--------------------------------------
# MAIN ENTRY POINT
#--------------------------------------
main() {
  local command="${1:-check}"
  shift || true

  # Parse global options
  for arg in "$@"; do
    case "$arg" in
      -v|--verbose) VERBOSE=true ;;
      --dry-run) DRY_RUN=true ;;
    esac
  done

  case "$command" in
    check|status)
      check_requirements
      ;;
    install)
      install_requirements
      ;;
    instructions|help)
      show_install_instructions
      ;;
    *)
      log_error "Unknown requirements command: $command"
      echo "Usage: $0 {check|install|instructions}" >&2
      return 1
      ;;
  esac
}

# Only run main if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
