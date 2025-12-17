#!/usr/bin/env bash
#
# config.sh - Configuration management for AutoVault
#
# Usage: source this file from any script that needs config access
#   source "$SCRIPT_DIR/lib/config.sh"
#
# Provides:
#   - Config file path (CONFIG_JSON)
#   - Default values for VAULT_ROOT, CUSTOMER_ID_WIDTH, etc.
#   - load_config() - reads config from JSON
#   - ensure_config_json() - writes config to JSON
#   - render_config_json() - generates JSON from current values
#   - Interactive config helpers: prompt_value(), prompt_list()
#

# Prevent multiple sourcing
[[ -n "${_CONFIG_SH_LOADED:-}" ]] && return 0
_CONFIG_SH_LOADED=1

# Ensure logging is available
if [[ -z "${_LOGGING_SH_LOADED:-}" ]]; then
  _LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "$_LIB_DIR/logging.sh"
fi

#--------------------------------------
# CONFIG FILE PATH
#--------------------------------------
# SCRIPT_DIR should be set by the calling script
# Default to parent of lib/ if not set
if [[ -z "${SCRIPT_DIR:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

CONFIG_JSON="${CONFIG_JSON:-"$SCRIPT_DIR/../config/cust-run-config.json"}"

#--------------------------------------
# DEFAULT VALUES
#--------------------------------------
VAULT_ROOT="${VAULT_ROOT:-"D:\\Obsidian\\Work-Vault"}"
CUSTOMER_ID_WIDTH="${CUSTOMER_ID_WIDTH:-3}"

# Initialize arrays if not already set
declare -ga CUSTOMER_IDS="${CUSTOMER_IDS[@]:-}"
declare -ga SECTIONS="${SECTIONS[@]:-}"

if [[ -z "${CUSTOMER_IDS[*]:-}" ]]; then
  CUSTOMER_IDS=(2 4 5 7 10 11 12 14 15 18 25 27 29 30)
fi

if [[ -z "${SECTIONS[*]:-}" ]]; then
  SECTIONS=("FP" "RAISED" "INFORMATIONS" "DIVERS")
fi

TEMPLATE_RELATIVE_ROOT="${TEMPLATE_RELATIVE_ROOT:-"_templates\\Run"}"

# Cleanup safety flag (must be true to allow deletion)
ENABLE_CLEANUP="${ENABLE_CLEANUP:-false}"

#--------------------------------------
# BACKUP DIRECTORY
#--------------------------------------
BACKUP_DIR="${BACKUP_DIR:-"$SCRIPT_DIR/../backups"}"

#--------------------------------------
# JSON RENDERING (requires python3)
#--------------------------------------
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
  ENABLE_CLEANUP="$ENABLE_CLEANUP" \
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
    "EnableCleanup": os.environ.get("ENABLE_CLEANUP", "false").lower() == "true",
}

print(json.dumps(payload, indent=2))
PY
}

#--------------------------------------
# WRITE CONFIG TO JSON
#--------------------------------------
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

#--------------------------------------
# LOAD CONFIG FROM JSON
#--------------------------------------
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
    # Read EnableCleanup (defaults to false if not present)
    local enable_cleanup_val
    enable_cleanup_val="$(jq -r '.EnableCleanup // false' "$CONFIG_JSON")"
    ENABLE_CLEANUP="$enable_cleanup_val"
  else
    # Config file doesn't exist - warn user and use defaults
    log_warn "Config file not found: $CONFIG_JSON"
    log_warn "Using default values. Run './cust-run-config.sh config' to create configuration."
    # Return success but with defaults (already set at top of file)
    return 0
  fi
}

#--------------------------------------
# INTERACTIVE PROMPTS
#--------------------------------------
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

#--------------------------------------
# EXPORT ENV VARS (for child scripts)
#--------------------------------------
export_cust_env() {
  # Export CONFIG_JSON so child scripts use the same config file
  export CONFIG_JSON
  # Export DRY_RUN flag for child scripts
  export DRY_RUN="${DRY_RUN:-false}"
  # Export log level
  export LOG_LEVEL="${LOG_LEVEL:-3}"
}

#--------------------------------------
# HELPER: Get formatted customer code
#--------------------------------------
get_cust_code() {
  local id="$1"
  printf "CUST-%0${CUSTOMER_ID_WIDTH}d" "$id"
}
