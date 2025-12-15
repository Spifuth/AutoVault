#!/usr/bin/env bash
#
# Test-CustRunStructure.sh
#
# VERIFICATION SCRIPT – CHECKS Run STRUCTURE AND INDEX FILES
#
# EXIT CODES:
#   0 if everything is OK
#   1 if there are missing elements

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

#######################################
# Configuration loading
#######################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SCRIPT="$SCRIPT_DIR/../cust-run-config.sh"
CONFIG_JSON="${CONFIG_JSON:-"$SCRIPT_DIR/../config/cust-run-config.json"}"

load_config() {
    if [[ -f "$CONFIG_SCRIPT" ]]; then
        write_log "INFO" "Loading configuration from $CONFIG_SCRIPT"
        if ! source "$CONFIG_SCRIPT"; then
            write_log "ERROR" "Failed to load configuration from $CONFIG_SCRIPT"
            return 1
        fi
    else
        write_log "WARN" "Configuration script not found at $CONFIG_SCRIPT; falling back to $CONFIG_JSON"

        if ! command -v jq >/dev/null 2>&1; then
            write_log "ERROR" "jq is required to read $CONFIG_JSON"
            return 1
        fi

        if [[ ! -f "$CONFIG_JSON" ]]; then
            write_log "ERROR" "Configuration file not found: $CONFIG_JSON"
            return 1
        fi

        VAULT_ROOT="$(jq -r '.VaultRoot // empty' "$CONFIG_JSON")"
        CUSTOMER_ID_WIDTH="$(jq -r '.CustomerIdWidth // empty' "$CONFIG_JSON")"
        mapfile -t CUSTOMER_IDS < <(jq -r '.CustomerIds[]?' "$CONFIG_JSON")
        mapfile -t SECTIONS < <(jq -r '.Sections[]?' "$CONFIG_JSON")
    fi

    if [[ ${#CUST_SECTIONS[@]:-0} -eq 0 && ${#SECTIONS[@]:-0} -gt 0 ]]; then
        CUST_SECTIONS=("${SECTIONS[@]}")
    fi

    if [[ -z "${CUSTOMER_ID_WIDTH:-}" ]]; then
        CUSTOMER_ID_WIDTH=3
    fi

    if [[ ${#CUST_SECTIONS[@]:-0} -eq 0 ]]; then
        CUST_SECTIONS=("FP" "RAISED" "INFORMATIONS" "DIVERS")
    fi

    if [[ -z "${VAULT_ROOT:-}" ]]; then
        write_log "ERROR" "VAULT_ROOT is not set. Configure cust-run-config.sh or provide $CONFIG_JSON."
        return 1
    fi

    if [[ ${#CUSTOMER_IDS[@]:-0} -eq 0 ]]; then
        write_log "ERROR" "No CUST ids defined in CUSTOMER_IDS. Update configuration before running tests."
        return 1
    fi

    return 0
}

#######################################
# Main
#######################################

errors=()
warnings=()

if ! load_config; then
    write_log "ERROR" "Unable to load configuration. Aborting verification."
    exit 1
fi

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
    warnings+=("$msg")
fi

get_cust_code() {
    local id="$1"
    printf "CUST-%0${CUSTOMER_ID_WIDTH}d" "$id"
}

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
    for section in "${CUST_SECTIONS[@]}"; do
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
            warnings+=("$msg")
        else
            write_log "DEBUG" "Hub contains reference to $expected_token"
        fi
    fi
done

if [[ ${#errors[@]} -eq 0 ]]; then
    if [[ ${#warnings[@]} -gt 0 ]]; then
        write_log "WARN" "VERIFICATION COMPLETE WITH WARNINGS – Review logged warnings."
        for warn in "${warnings[@]}"; do
            echo "  - $warn"
        done
    else
        write_log "INFO" "VERIFICATION SUCCESS – Run structure and all CUST indexes are present."
    fi
    exit 0
else
    write_log "ERROR" "VERIFICATION FAILED – Issues detected:"
    for err in "${errors[@]}"; do
        echo "  - $err"
    done
    if [[ ${#warnings[@]} -gt 0 ]]; then
        write_log "WARN" "Additional warnings encountered:"
        for warn in "${warnings[@]}"; do
            echo "  - $warn"
        done
    fi
    exit 1
fi
