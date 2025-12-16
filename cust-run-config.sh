#!/usr/bin/env bash
# cust-run-config.sh
# Orchestrator + config for CUST Run PowerShell scripts.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_JSON="${CONFIG_JSON:-"$SCRIPT_DIR/config/cust-run-config.json"}"

#--------------------------------------
# GLOBAL FLAGS
#--------------------------------------
# Log levels: 0=quiet, 1=error, 2=warn, 3=info (default), 4=debug
LOG_LEVEL="${LOG_LEVEL:-3}"

#--------------------------------------
# COLORS + LOGGING HELPERS
#--------------------------------------
# NO_COLOR environment variable support (https://no-color.org/)
# Can also be set via --no-color flag
NO_COLOR="${NO_COLOR:-}"

setup_colors() {
  if [[ -n "$NO_COLOR" ]] || [[ ! -t 2 ]]; then
    COLOR_BLUE=""
    COLOR_YELLOW=""
    COLOR_RED=""
    COLOR_GREEN=""
    COLOR_GRAY=""
    COLOR_RESET=""
  else
    COLOR_BLUE="\033[34m"
    COLOR_YELLOW="\033[33m"
    COLOR_RED="\033[31m"
    COLOR_GREEN="\033[32m"
    COLOR_GRAY="\033[90m"
    COLOR_RESET="\033[0m"
  fi
}

# Initialize colors (may be re-called after parsing --no-color flag)
setup_colors

log_debug() {
  [[ "$LOG_LEVEL" -ge 4 ]] && printf "%b[DEBUG]%b %s\n" "$COLOR_GRAY" "$COLOR_RESET" "$1" >&2
  return 0
}

log_info() {
  [[ "$LOG_LEVEL" -ge 3 ]] && printf "%b[INFO ]%b %s\n" "$COLOR_BLUE" "$COLOR_RESET" "$1" >&2
  return 0
}

log_warn() {
  [[ "$LOG_LEVEL" -ge 2 ]] && printf "%b[WARN ]%b %s\n" "$COLOR_YELLOW" "$COLOR_RESET" "$1" >&2
  return 0
}

log_error() {
  [[ "$LOG_LEVEL" -ge 1 ]] && printf "%b[ERROR]%b %s\n" "$COLOR_RED" "$COLOR_RESET" "$1" >&2
  return 0
}

log_success() {
  [[ "$LOG_LEVEL" -ge 3 ]] && printf "%b[OK   ]%b %s\n" "$COLOR_GREEN" "$COLOR_RESET" "$1" >&2
  return 0
}

log_success() {
  printf "%b[OK   ]%b %s\n" "$COLOR_GREEN" "$COLOR_RESET" "$1" >&2
}

#######################################
# REQUIREMENTS CHECK & AUTO-INSTALL
#######################################

check_requirements() {
  local missing=()
  
  if ! command -v jq >/dev/null 2>&1; then
    missing+=("jq")
  fi
  
  if ! command -v python3 >/dev/null 2>&1; then
    missing+=("python3")
  fi
  
  if [[ ${#missing[@]} -eq 0 ]]; then
    return 0
  fi
  
  echo "${missing[*]}"
  return 1
}

detect_package_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    echo "apt"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif command -v yum >/dev/null 2>&1; then
    echo "yum"
  elif command -v pacman >/dev/null 2>&1; then
    echo "pacman"
  elif command -v zypper >/dev/null 2>&1; then
    echo "zypper"
  elif command -v brew >/dev/null 2>&1; then
    echo "brew"
  elif command -v apk >/dev/null 2>&1; then
    echo "apk"
  else
    echo ""
  fi
}

install_requirements() {
  local missing
  missing=$(check_requirements) || true
  
  if [[ -z "$missing" ]]; then
    log_info "All requirements are already installed"
    return 0
  fi
  
  log_warn "Missing requirements: $missing"
  
  local pkg_manager
  pkg_manager=$(detect_package_manager)
  
  if [[ -z "$pkg_manager" ]]; then
    log_error "No supported package manager found"
    log_error "Please install manually: $missing"
    return 1
  fi
  
  log_info "Detected package manager: $pkg_manager"
  
  local confirm
  printf "Install missing requirements using %s? [Y/n]: " "$pkg_manager" >&2
  read -r confirm
  if [[ "$confirm" =~ ^[Nn] ]]; then
    log_warn "Installation cancelled"
    return 1
  fi
  
  local install_cmd
  case "$pkg_manager" in
    apt)
      install_cmd="sudo apt-get update && sudo apt-get install -y"
      ;;
    dnf)
      install_cmd="sudo dnf install -y"
      ;;
    yum)
      install_cmd="sudo yum install -y"
      ;;
    pacman)
      install_cmd="sudo pacman -S --noconfirm"
      ;;
    zypper)
      install_cmd="sudo zypper install -y"
      ;;
    brew)
      install_cmd="brew install"
      ;;
    apk)
      install_cmd="sudo apk add"
      ;;
  esac
  
  # Map package names for different managers
  local packages=""
  for pkg in $missing; do
    case "$pkg" in
      python3)
        case "$pkg_manager" in
          pacman) packages="$packages python" ;;
          *) packages="$packages python3" ;;
        esac
        ;;
      *)
        packages="$packages $pkg"
        ;;
    esac
  done
  
  log_info "Running: $install_cmd$packages"
  if eval "$install_cmd$packages"; then
    log_info "Requirements installed successfully"
    return 0
  else
    log_error "Failed to install requirements"
    return 1
  fi
}

#######################################
# CONFIGURATION SOURCE
#######################################

# Base values used to seed cust-run-config.json. Adjust these to match your
# vault and customer list. Re-running the script will refresh the JSON to match
# these values (or environment overrides) so Bash and PowerShell stays aligned.
VAULT_ROOT="${VAULT_ROOT:-"D:\\Obsidian\\Work-Vault"}"
CUSTOMER_ID_WIDTH="${CUSTOMER_ID_WIDTH:-3}"

# Initialize arrays if not already set
# Use declare -g for global scope when sourced from a function
declare -ga CUSTOMER_IDS="${CUSTOMER_IDS[@]:-}"
declare -ga SECTIONS="${SECTIONS[@]:-}"

if [[ -z "${CUSTOMER_IDS[*]:-}" ]]; then
  CUSTOMER_IDS=(2 4 5 7 10 11 12 14 15 18 25 27 29 30)
fi

if [[ -z "${SECTIONS[*]:-}" ]]; then
  SECTIONS=("FP" "RAISED" "INFORMATIONS" "DIVERS")
fi

TEMPLATE_RELATIVE_ROOT="${TEMPLATE_RELATIVE_ROOT:-"_templates\\Run"}"

#######################################
# INTERACTIVE CONFIGURATION
#######################################

prompt_value() {
  local prompt="$1"
  local default="$2"
  local result

  if [[ -n "$default" ]]; then
    printf "%s [%s]: " "$prompt" "$default" >&2
  else
    printf "%s: " "$prompt" >&2
  fi

  read -r result
  if [[ -z "$result" ]]; then
    echo "$default"
  else
    echo "$result"
  fi
}

prompt_list() {
  local prompt="$1"
  shift
  local -a defaults=("$@")
  local default_str="${defaults[*]}"
  local result

  printf "%s (space-separated) [%s]: " "$prompt" "$default_str" >&2
  read -r result

  if [[ -z "$result" ]]; then
    echo "$default_str"
  else
    echo "$result"
  fi
}

interactive_config() {
  log_info "Interactive configuration mode"
  log_info "Press Enter to keep current/default values"
  echo >&2

  # Display current configuration
  echo "Current configuration:" >&2
  echo "  1. VaultRoot:            $VAULT_ROOT" >&2
  echo "  2. CustomerIdWidth:      $CUSTOMER_ID_WIDTH" >&2
  echo "  3. CustomerIds:          ${CUSTOMER_IDS[*]}" >&2
  echo "  4. Sections:             ${SECTIONS[*]}" >&2
  echo "  5. TemplateRelativeRoot: $TEMPLATE_RELATIVE_ROOT" >&2
  echo >&2

  # VaultRoot
  local new_vault_root
  new_vault_root=$(prompt_value "Vault root path" "$VAULT_ROOT")
  VAULT_ROOT="$new_vault_root"

  # CustomerIdWidth
  local new_width
  new_width=$(prompt_value "Customer ID width (padding)" "$CUSTOMER_ID_WIDTH")
  CUSTOMER_ID_WIDTH="$new_width"

  # CustomerIds
  local new_ids_str
  new_ids_str=$(prompt_list "Customer IDs" "${CUSTOMER_IDS[@]}")
  read -ra CUSTOMER_IDS <<< "$new_ids_str"

  # Sections
  local new_sections_str
  new_sections_str=$(prompt_list "Sections" "${SECTIONS[@]}")
  read -ra SECTIONS <<< "$new_sections_str"

  # TemplateRelativeRoot
  local new_template_root
  new_template_root=$(prompt_value "Template relative root" "$TEMPLATE_RELATIVE_ROOT")
  TEMPLATE_RELATIVE_ROOT="$new_template_root"

  echo >&2
  log_info "Configuration summary:"
  echo "  VaultRoot:            $VAULT_ROOT" >&2
  echo "  CustomerIdWidth:      $CUSTOMER_ID_WIDTH" >&2
  echo "  CustomerIds:          ${CUSTOMER_IDS[*]}" >&2
  echo "  Sections:             ${SECTIONS[*]}" >&2
  echo "  TemplateRelativeRoot: $TEMPLATE_RELATIVE_ROOT" >&2
  echo >&2

  local confirm
  printf "Save this configuration? [Y/n]: " >&2
  read -r confirm
  if [[ "$confirm" =~ ^[Nn] ]]; then
    log_warn "Configuration cancelled"
    return 1
  fi

  # Force write the new config
  if ! ensure_config_json; then
    log_error "Failed to write configuration"
    return 1
  fi

  log_info "Configuration saved to $CONFIG_JSON"
}

#######################################
# CONFIG (written to + loaded from cust-run-config.json)
#######################################

render_config_json() {
  if ! command -v python3 >/dev/null 2>&1; then
    log_error "python3 is required to create $CONFIG_JSON"
    return 1
  fi

  VAULT_ROOT="$VAULT_ROOT" \
  CUSTOMER_ID_WIDTH="$CUSTOMER_ID_WIDTH" \
  CUSTOMER_IDS_LIST="${CUSTOMER_IDS[*]}" \
  SECTIONS_LIST="${SECTIONS[*]}" \
  TEMPLATE_RELATIVE_ROOT="$TEMPLATE_RELATIVE_ROOT" \
  python3 - <<'PY'
import json
import os


def split_list(name: str):
    raw = os.environ.get(name, "")
    return [item for item in raw.split() if item]


payload = {
    "VaultRoot": os.environ.get("VAULT_ROOT", ""),
    "CustomerIdWidth": int(os.environ.get("CUSTOMER_ID_WIDTH", "3")),
    "CustomerIds": [int(x) for x in split_list("CUSTOMER_IDS_LIST")],
    "Sections": split_list("SECTIONS_LIST") or ["FP", "RAISED", "INFORMATIONS", "DIVERS"],
    "TemplateRelativeRoot": os.environ.get("TEMPLATE_RELATIVE_ROOT", "_templates\\\\Run"),
}

print(json.dumps(payload, indent=2))
PY
}

ensure_config_json() {
  local tmp
  tmp="$(mktemp)"

  if ! render_config_json >"$tmp"; then
    rm -f "$tmp"
    return 1
  fi

  if [[ ! -f "$CONFIG_JSON" ]] || ! cmp -s "$tmp" "$CONFIG_JSON"; then
    # Ensure config directory exists
    local config_dir
    config_dir="$(dirname "$CONFIG_JSON")"
    if [[ ! -d "$config_dir" ]]; then
      log_info "Creating config directory: $config_dir"
      mkdir -p "$config_dir"
    fi
    log_info "Writing configuration file: $CONFIG_JSON"
    mv "$tmp" "$CONFIG_JSON"
  else
    rm "$tmp"
  fi
}

load_config() {
  if ! command -v jq >/dev/null 2>&1; then
    log_error "jq is required to read $CONFIG_JSON"
    return 1
  fi

  # If config file already exists, read values from it FIRST before calling ensure_config_json
  # This prevents overwriting saved config with defaults
  if [[ -f "$CONFIG_JSON" ]]; then
    VAULT_ROOT="$(jq -r '.VaultRoot' "$CONFIG_JSON")"
    # Expand tilde to home directory (~ is not expanded when read from JSON)
    VAULT_ROOT="${VAULT_ROOT/#\~/$HOME}"
    CUSTOMER_ID_WIDTH="$(jq -r '.CustomerIdWidth // 3' "$CONFIG_JSON")"
    # Declare as global before mapfile to avoid local variable creation in function context
    declare -ga CUSTOMER_IDS
    declare -ga SECTIONS
    mapfile -t CUSTOMER_IDS < <(jq -r '.CustomerIds[]' "$CONFIG_JSON")
    mapfile -t SECTIONS < <(jq -r '.Sections[]' "$CONFIG_JSON")
    TEMPLATE_RELATIVE_ROOT="$(jq -r '.TemplateRelativeRoot' "$CONFIG_JSON")"
  else
    # Config file doesn't exist yet - create it with current (default) values
    if ! ensure_config_json; then
      return 1
    fi
  fi
}

if ! load_config; then
  # When sourced, return non-zero so callers can handle the error
  return 1 2>/dev/null || exit 1
fi

#######################################
# INTERNAL: export env vars for pwsh
#######################################
export_cust_env() {
  export CUST_VAULT_ROOT="$VAULT_ROOT"
  export CUST_CUSTOMER_ID_WIDTH="$CUSTOMER_ID_WIDTH"
  # join arrays with spaces
  export CUST_CUSTOMER_IDS="${CUSTOMER_IDS[*]}"
  export CUST_SECTIONS="${SECTIONS[*]}"
  export CUST_TEMPLATE_RELATIVE_ROOT="$TEMPLATE_RELATIVE_ROOT"
  export LOG_LEVEL="$LOG_LEVEL"
}

run_bash() {
  local script="$1"
  shift || true
  LOG_LEVEL="$LOG_LEVEL" bash "$SCRIPT_DIR/bash/$script" "$@"
}

#######################################
# STATUS COMMAND
#######################################
show_status() {
  echo "=== AutoVault Configuration Status ==="
  echo
  echo "Configuration file: $CONFIG_JSON"
  if [[ -f "$CONFIG_JSON" ]]; then
    echo "  Status: ✓ exists"
  else
    echo "  Status: ✗ not found"
    return 1
  fi
  echo
  echo "Vault Root: $VAULT_ROOT"
  if [[ -d "$VAULT_ROOT" ]]; then
    echo "  Status: ✓ directory exists"
  else
    echo "  Status: ✗ directory not found"
  fi
  echo
  echo "Customer ID Width: $CUSTOMER_ID_WIDTH"
  echo "Template Root: $TEMPLATE_RELATIVE_ROOT"
  echo
  echo "Sections (${#SECTIONS[@]}):"
  for section in "${SECTIONS[@]}"; do
    echo "  - $section"
  done
  echo
  echo "Customers (${#CUSTOMER_IDS[@]}):"
  local run_path="$VAULT_ROOT/Run"
  for id in "${CUSTOMER_IDS[@]}"; do
    local code
    code=$(printf "CUST-%0${CUSTOMER_ID_WIDTH}d" "$id")
    local cust_path="$run_path/$code"
    if [[ -d "$cust_path" ]]; then
      echo "  ✓ $code"
    else
      echo "  ✗ $code (not created)"
    fi
  done
  echo
  echo "Run folder: $run_path"
  if [[ -d "$run_path" ]]; then
    echo "  Status: ✓ exists"
    local folder_count
    folder_count=$(find "$run_path" -maxdepth 1 -type d -name "CUST-*" 2>/dev/null | wc -l)
    echo "  CUST folders: $folder_count"
  else
    echo "  Status: ✗ not created"
  fi
  echo
  echo "Hub file: $VAULT_ROOT/Run-Hub.md"
  if [[ -f "$VAULT_ROOT/Run-Hub.md" ]]; then
    echo "  Status: ✓ exists"
  else
    echo "  Status: ✗ not created"
  fi
}

#######################################
# CLI (only when executed directly)
#######################################
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  usage() {
    cat <<'EOF'
Usage: cust-run-config.sh [options] <command>

Options:
  -v, --verbose   Show debug output (LOG_LEVEL=4)
  -q, --quiet     Show only errors (LOG_LEVEL=1)
  --silent        Show nothing (LOG_LEVEL=0)
  --no-color      Disable colored output (also respects NO_COLOR env var)
  -h, --help      Show this help message

Commands:
  install     Check and install missing requirements (jq, python3)
  config      Interactive configuration wizard
  status      Show configuration and structure status
  structure   Create / refresh CUST Run folder structure
  templates   Apply markdown templates to indexes
  test        Verify structure & indexes
  cleanup     Remove CUST folders (uses Cleanup script safety flags)

Examples:
  cust-run-config.sh install
  cust-run-config.sh config
  cust-run-config.sh structure
  cust-run-config.sh -v structure    # verbose mode
  cust-run-config.sh -q cleanup      # quiet mode
  cust-run-config.sh --no-color test
EOF
  }

  # Parse options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -v|--verbose)
        LOG_LEVEL=4
        shift
        ;;
      -q|--quiet)
        LOG_LEVEL=1
        shift
        ;;
      --silent)
        LOG_LEVEL=0
        shift
        ;;
      --no-color)
        NO_COLOR=1
        setup_colors
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -*)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
      *)
        break
        ;;
    esac
  done

  cmd="${1:-}"

  if [[ -z "$cmd" ]]; then
    usage
    exit 1
  fi

  log_debug "Log level: $LOG_LEVEL"
  log_debug "Command: $cmd"

  # Handle install command before loading config (which requires jq/python3)
  if [[ "$cmd" == "install" || "$cmd" == "requirements" ]]; then
    install_requirements
    exit $?
  fi

  export_cust_env

  case "$cmd" in
    config|setup|init)
      interactive_config
      ;;
    status)
      show_status
      ;;
    structure|new)
      log_info "Using configuration from $CONFIG_JSON"
      run_bash "New-CustRunStructure.sh"
      ;;
    templates|apply)
      log_info "Using configuration from $CONFIG_JSON"
      run_bash "Apply-CustRunTemplates.sh"
      ;;
    test|verify)
      log_info "Using configuration from $CONFIG_JSON"
      run_bash "Test-CustRunStructure.sh"
      ;;
    cleanup)
      log_warn "Using configuration from $CONFIG_JSON"
      run_bash "Cleanup-CustRunStructure.sh"
      ;;
    *)
      log_error "Unknown command: $cmd"
      echo
      usage
      exit 1
      ;;
  esac
fi
