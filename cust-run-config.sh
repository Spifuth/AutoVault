#!/usr/bin/env bash
# cust-run-config.sh
# Orchestrator + config for CUST Run PowerShell scripts.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_JSON="${CONFIG_JSON:-"$SCRIPT_DIR/config/cust-run-config.json"}"

#--------------------------------------
# COLORS + LOGGING HELPERS
#--------------------------------------
if [[ -t 2 ]]; then
  COLOR_BLUE="\033[34m"
  COLOR_YELLOW="\033[33m"
  COLOR_RED="\033[31m"
  COLOR_RESET="\033[0m"
else
  COLOR_BLUE=""
  COLOR_YELLOW=""
  COLOR_RED=""
  COLOR_RESET=""
fi

log_info() {
  printf "%b[INFO ]%b %s\n" "$COLOR_BLUE" "$COLOR_RESET" "$1" >&2
}

log_warn() {
  printf "%b[WARN ]%b %s\n" "$COLOR_YELLOW" "$COLOR_RESET" "$1" >&2
}

log_error() {
  printf "%b[ERROR]%b %s\n" "$COLOR_RED" "$COLOR_RESET" "$1" >&2
}

#######################################
# CONFIGURATION SOURCE
#######################################

# Base values used to seed cust-run-config.json. Adjust these to match your
# vault and customer list. Re-running the script will refresh the JSON to match
# these values (or environment overrides) so Bash and PowerShell stays aligned.
VAULT_ROOT="${VAULT_ROOT:-"D:\\Obsidian\\Work-Vault"}"
CUSTOMER_ID_WIDTH="${CUSTOMER_ID_WIDTH:-3}"

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

  CUSTOMER_IDS_LIST="${CUSTOMER_IDS[*]}" \
  SECTIONS_LIST="${SECTIONS[*]}" \
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

  if ! ensure_config_json; then
    return 1
  fi

  if [[ ! -f "$CONFIG_JSON" ]]; then
    log_error "Configuration file not found: $CONFIG_JSON"
    return 1
  fi

  VAULT_ROOT="$(jq -r '.VaultRoot' "$CONFIG_JSON")"
  CUSTOMER_ID_WIDTH="$(jq -r '.CustomerIdWidth // 3' "$CONFIG_JSON")"
  mapfile -t CUSTOMER_IDS < <(jq -r '.CustomerIds[]' "$CONFIG_JSON")
  mapfile -t SECTIONS < <(jq -r '.Sections[]' "$CONFIG_JSON")
  TEMPLATE_RELATIVE_ROOT="$(jq -r '.TemplateRelativeRoot' "$CONFIG_JSON")"
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
}

run_bash() {
  local script="$1"
  shift || true
  bash "$SCRIPT_DIR/bash/$script" "$@"
}

#######################################
# CLI (only when executed directly)
#######################################
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  usage() {
    cat <<'EOF'
Usage: cust-run-config.sh <command>

Commands:
  config      Interactive configuration wizard
  structure   Create / refresh CUST Run folder structure
  templates   Apply markdown templates to indexes
  test        Verify structure & indexes
  cleanup     Remove CUST folders (uses Cleanup script safety flags)

Examples:
  cust-run-config.sh config
  cust-run-config.sh structure
  cust-run-config.sh templates
  cust-run-config.sh test
  cust-run-config.sh cleanup
EOF
  }

  cmd="${1:-}"

  if [[ -z "$cmd" ]]; then
    usage
    exit 1
  fi

  export_cust_env

  case "$cmd" in
    config|setup|init)
      interactive_config
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
