#!/usr/bin/env bash
#
# Cleanup-CustRunStructure.sh
#
# DANGEROUS SCRIPT – WILL DELETE CUST STRUCTURE UNDER Run
#

#######################################
# Configuration (shared)
#######################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_PATH="$SCRIPT_DIR/cust-run-config.sh"

if [[ ! -f "$CONFIG_PATH" ]]; then
    echo "Config file not found: $CONFIG_PATH" >&2
    exit 1
fi

# shellcheck disable=SC1091
source "$CONFIG_PATH"

validate_config() {
    local errors=0

    if [[ -z "${VAULT_ROOT:-}" ]]; then
        echo "VAULT_ROOT is not set in $CONFIG_PATH" >&2
        errors=1
    fi

    if [[ -z "${CUSTOMER_ID_WIDTH:-}" || ! "$CUSTOMER_ID_WIDTH" =~ ^[0-9]+$ ]]; then
        echo "CUSTOMER_ID_WIDTH must be a numeric value in $CONFIG_PATH" >&2
        errors=1
    fi

    if [[ ${#CUSTOMER_IDS[@]:-0} -eq 0 ]]; then
        echo "CUSTOMER_IDS is empty in $CONFIG_PATH" >&2
        errors=1
    fi

    return $errors
}

validate_config || exit 1

# Safety flags
ENABLE_DELETION=false   # MUST be set to true to delete
REMOVE_HUB=false        # Set to true if you also want to remove Run-Hub.md

#######################################
# Helper functions
#######################################

write_log() {
    local level="${1:-INFO}"
    shift
    local message="$*"

    local utc localtime
    utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    localtime="$(date +"%Y-%m-%dT%H:%M:%S%z")"

    echo "[$level][UTC:$utc][Local:$localtime] $message"
}

get_cust_code() {
    local id="$1"
    printf "CUST-%0${CUSTOMER_ID_WIDTH}d" "$id"
}

#######################################
# Main
#######################################

if [[ "$ENABLE_DELETION" != true ]]; then
    write_log "ERROR" "ABORT: Cleanup disabled. Set ENABLE_DELETION=true inside the script if you really want to delete."
    exit 1
fi

if [[ ${#CUSTOMER_IDS[@]} -eq 0 ]]; then
    write_log "WARN" "No CUST ids defined in CUSTOMER_IDS. Nothing to clean."
    exit 0
fi

RUN_PATH="$VAULT_ROOT/Run"

write_log "WARN" "Starting cleanup of CUST folders under: $RUN_PATH"

for id in "${CUSTOMER_IDS[@]}"; do
    if ! [[ "$id" =~ ^[0-9]+$ ]]; then
        write_log "ERROR" "Invalid CUST id (not an integer): $id"
        continue
    fi

    code="$(get_cust_code "$id")"
    cust_root="$RUN_PATH/$code"

    if [[ -d "$cust_root" ]]; then
        write_log "WARN" "Removing CUST folder: $cust_root"
        rm -rf -- "$cust_root"
    else
        write_log "DEBUG" "CUST folder not found (skip): $cust_root"
    fi
done

if [[ "$REMOVE_HUB" == true ]]; then
    hub_path="$VAULT_ROOT/Run-Hub.md"
    if [[ -f "$hub_path" ]]; then
        write_log "WARN" "Removing hub file: $hub_path"
        rm -f -- "$hub_path"
    else
        write_log "DEBUG" "Hub file not found (skip): $hub_path"
    fi
fi

write_log "INFO" "Cleanup completed."
