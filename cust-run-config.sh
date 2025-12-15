#!/usr/bin/env bash
# cust-run-config.sh
# Orchestrator + config for CUST Run PowerShell scripts.

# When sourced, avoid changing caller shell options; when executed directly, enable safety flags.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#######################################
# CONFIG (edit here)
#######################################

# Root of your Obsidian vault
VAULT_ROOT="/mnt/c/Users/ncaluye/scripts/powershell/"

# Padding for CUST id (3 -> CUST-002)
CUSTOMER_ID_WIDTH=3

# List of customers (just the numeric IDs)
CUSTOMER_IDS=(2 4 5 7 10 11 12 14 15 18 25 27 29 30 999)

# Sections inside each CUST Run folder
SECTIONS=(FP RAISED INFORMATIONS DIVERS)

# Templates root, relative to VAULT_ROOT (used by Apply-CustRunTemplates.ps1)
TEMPLATE_RELATIVE_ROOT="_templates\Run"

# Convenience alias for bash helper scripts
CUST_SECTIONS=("${SECTIONS[@]}")

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
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  usage() {
    cat <<EOF
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
