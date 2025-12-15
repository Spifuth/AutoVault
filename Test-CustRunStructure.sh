#!/usr/bin/env bash
#
# Test-CustRunStructure.sh
#
# VERIFICATION SCRIPT – CHECKS Run STRUCTURE AND INDEX FILES
#
# EXIT CODES:
#   0 if everything is OK
#   1 if there are missing elements
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

    if [[ ${#SECTIONS[@]:-0} -eq 0 && ${#CUST_SECTIONS[@]:-0} -gt 0 ]]; then
        SECTIONS=("${CUST_SECTIONS[@]}")
    fi

    if [[ ${#SECTIONS[@]:-0} -eq 0 ]]; then
        echo "SECTIONS is empty in $CONFIG_PATH" >&2
        errors=1
    fi

    return $errors
}

validate_config || exit 1

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

errors=()

# Basic checks
if [[ ! -d "$VAULT_ROOT" ]]; then
    msg="Vault root does NOT exist: $VAULT_ROOT"
    write_log "ERROR" "$msg"
    errors+=("$msg")
fi

RUN_PATH="$VAULT_ROOT/Run"
if [[ ! -d "$RUN_PATH" ]]; then
    msg="Run folder does NOT exist: $RUN_PATH"
    write_log "ERROR" "$msg"
    errors+=("$msg")
else
    write_log "INFO" "Run folder exists: $RUN_PATH"
fi

HUB_PATH="$VAULT_ROOT/Run-Hub.md"
hub_content=""
if [[ ! -f "$HUB_PATH" ]]; then
    msg="Run-Hub.md does NOT exist: $HUB_PATH"
    write_log "ERROR" "$msg"
    errors+=("$msg")
else
    write_log "INFO" "Hub file exists: $HUB_PATH"
    hub_content="$(<"$HUB_PATH")"
fi

if [[ ${#CUSTOMER_IDS[@]} -eq 0 ]]; then
    msg="No CUST ids defined in CUSTOMER_IDS. Nothing to verify."
    write_log "WARN" "$msg"
    errors+=("$msg")
fi

for id in "${CUSTOMER_IDS[@]}"; do
    # En PS ton script planterait sur INTERNE: ici on vérifie proprement.
    if ! [[ "$id" =~ ^[0-9]+$ ]]; then
        msg="Invalid CUST id (not an integer): $id"
        write_log "ERROR" "$msg"
        errors+=("$msg")
        continue
    fi

    code="$(get_cust_code "$id")"
    cust_root="$RUN_PATH/$code"

    if [[ ! -d "$cust_root" ]]; then
        msg="MISSING CUST folder: $cust_root"
        write_log "ERROR" "$msg"
        errors+=("$msg")
        continue
    else
        write_log "INFO" "CUST folder OK: $cust_root"
    fi

    # Root index
    cust_index_path="$cust_root/$code-Index.md"
    if [[ ! -f "$cust_index_path" ]]; then
        msg="MISSING root index for ${code}: $cust_index_path"
        write_log "ERROR" "$msg"
        errors+=("$msg")
    else
        write_log "DEBUG" "Root index OK: $cust_index_path"
    fi

    # Subfolders + indexes
    for section in "${SECTIONS[@]}"; do
        sub_folder_name="${code}-${section}"
        sub_folder_path="$cust_root/$sub_folder_name"

        if [[ ! -d "$sub_folder_path" ]]; then
            msg="MISSING subfolder $sub_folder_name for ${code}: $sub_folder_path"
            write_log "ERROR" "$msg"
            errors+=("$msg")
            continue
        else
            write_log "DEBUG" "Subfolder OK: $sub_folder_path"
        fi

        sub_index_path="$sub_folder_path/$sub_folder_name-Index.md"
        if [[ ! -f "$sub_index_path" ]]; then
            msg="MISSING subfolder index $sub_folder_name for ${code}: $sub_index_path"
            write_log "ERROR" "$msg"
            errors+=("$msg")
        else
            write_log "DEBUG" "Subfolder index OK: $sub_index_path"
        fi
    done

    # Optional: hub contains link to CUST-XXX-Index
    if [[ -n "$hub_content" ]]; then
        expected_token="${code}-Index"
        if [[ "$hub_content" != *"$expected_token"* ]]; then
            msg="Hub file does not contain reference to $expected_token"
            write_log "WARN" "$msg"
            errors+=("$msg")
        else
            write_log "DEBUG" "Hub contains reference to $expected_token"
        fi
    fi
done

if [[ ${#errors[@]} -eq 0 ]]; then
    write_log "INFO" "VERIFICATION SUCCESS – Run structure and all CUST indexes are present."
    exit 0
else
    write_log "ERROR" "VERIFICATION FAILED – Issues detected:"
    for err in "${errors[@]}"; do
        echo "  - $err"
    done
    exit 1
fi
