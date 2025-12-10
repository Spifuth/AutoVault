#!/usr/bin/env bash
# cust-run-config.sh
# Orchestrator + config for CUST Run PowerShell scripts.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_JSON="${CONFIG_JSON:-"$SCRIPT_DIR/cust-run-config.json"}"

#######################################
# CONFIGURATION SOURCE
#######################################

# Base values used to seed cust-run-config.json. Adjust these to match your
# vault and customer list. Re-running the script will refresh the JSON to match
# these values (or environment overrides) so Bash and PowerShell stay aligned.
VAULT_ROOT="${VAULT_ROOT:-"D:\\Obsidian\\Work-Vault"}"
CUSTOMER_ID_WIDTH="${CUSTOMER_ID_WIDTH:-3}"

if [[ ${#CUSTOMER_IDS[@]:-0} -eq 0 ]]; then
  CUSTOMER_IDS=(2 4 5 7 10 11 12 14 15 18 25 27 29 30)
fi

if [[ ${#SECTIONS[@]:-0} -eq 0 ]]; then
  SECTIONS=("FP" "RAISED" "INFORMATIONS" "DIVERS")
fi

TEMPLATE_RELATIVE_ROOT="${TEMPLATE_RELATIVE_ROOT:-"_templates\\Run"}"

#######################################
# CONFIG (written to + loaded from cust-run-config.json)
#######################################

render_config_json() {
  if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 is required to create $CONFIG_JSON" >&2
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
    echo "INFO: Writing configuration file: $CONFIG_JSON" >&2
    mv "$tmp" "$CONFIG_JSON"
  else
    rm "$tmp"
  fi
}

load_config() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required to read $CONFIG_JSON" >&2
    return 1
  fi

  if ! ensure_config_json; then
    return 1
  fi

  if [[ ! -f "$CONFIG_JSON" ]]; then
    echo "ERROR: Configuration file not found: $CONFIG_JSON" >&2
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

run_pwsh() {
  local script="$1"
  shift || true
  pwsh -NoLogo -NoProfile -File "$SCRIPT_DIR/$script" "$@"
}

#######################################
# CLI (only when executed directly)
#######################################
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  usage() {
    cat <<'EOF'
Usage: $(basename "$0") <command>

Commands:
  structure   Create / refresh CUST Run folder structure
  templates   Apply markdown templates to indexes
  test        Verify structure & indexes
  cleanup     Remove CUST folders (uses Cleanup script safety flags)

Examples:
  $(basename "$0") structure
  $(basename "$0") templates
  $(basename "$0") test
  $(basename "$0") cleanup
EOF
  }

  cmd="${1:-}"

  if [[ -z "$cmd" ]]; then
    usage
    exit 1
  fi

  export_cust_env

  case "$cmd" in
    structure|new)
      run_pwsh "New-CustRunStructure.ps1"
      ;;
    templates|apply)
      run_pwsh "Apply-CustRunTemplates.ps1"
      ;;
    test|verify)
      run_pwsh "Test-CustRunStructure.ps1"
      ;;
    cleanup)
      run_pwsh "Cleanup-CustRunStructure.ps1"
      ;;
    *)
      echo "Unknown command: $cmd" >&2
      echo
      usage
      exit 1
      ;;
  esac
fi
