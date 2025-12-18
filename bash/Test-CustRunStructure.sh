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

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared libraries
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/config.sh"

#######################################
# Main
#######################################

errors=()
warnings=()

if ! load_config; then
    log_error "Unable to load configuration. Aborting verification."
    exit 1
fi

# Normalize VAULT_ROOT path
VAULT_ROOT="${VAULT_ROOT/#\~/$HOME}"
if [[ "$VAULT_ROOT" == *"\\"* ]]; then
    VAULT_ROOT="${VAULT_ROOT//\\//}"
fi

# Basic checks
if [[ ! -d "$VAULT_ROOT" ]]; then
    msg="Vault root does NOT exist: $VAULT_ROOT"
    log_error "$msg"
    errors+=("$msg")
fi

RUN_PATH="$VAULT_ROOT/Run"
if [[ ! -d "$RUN_PATH" ]]; then
    msg="Run folder does NOT exist: $RUN_PATH"
    log_error "$msg"
    errors+=("$msg")
else
    log_info "Run folder exists: $RUN_PATH"
fi

HUB_PATH="$VAULT_ROOT/Run-Hub.md"
hub_content=""
if [[ ! -f "$HUB_PATH" ]]; then
    msg="Run-Hub.md does NOT exist: $HUB_PATH"
    log_error "$msg"
    errors+=("$msg")
else
    log_info "Hub file exists: $HUB_PATH"
    hub_content="$(<"$HUB_PATH")"
fi

if [[ ${#CUSTOMER_IDS[@]} -eq 0 ]]; then
    msg="No CUST ids defined in CUSTOMER_IDS. Nothing to verify."
    log_warn "$msg"
    warnings+=("$msg")
fi

for id in "${CUSTOMER_IDS[@]}"; do
    # En PS ton script planterait sur INTERNE: ici on vérifie proprement.
    if ! [[ "$id" =~ ^[0-9]+$ ]]; then
        msg="Invalid CUST id (not an integer): $id"
        log_error "$msg"
        errors+=("$msg")
        continue
    fi

    code="$(get_cust_code "$id")"
    cust_root="$RUN_PATH/$code"

    if [[ ! -d "$cust_root" ]]; then
        msg="MISSING CUST folder: $cust_root"
        log_error "$msg"
        errors+=("$msg")
        continue
    else
        log_info "CUST folder OK: $cust_root"
    fi

    # Root index
    cust_index_path="$cust_root/$code-Index.md"
    if [[ ! -f "$cust_index_path" ]]; then
        msg="MISSING root index for ${code}: $cust_index_path"
        log_error "$msg"
        errors+=("$msg")
    else
        log_debug "Root index OK: $cust_index_path"
    fi

    # Subfolders + indexes
    for section in "${SECTIONS[@]}"; do
        sub_folder_name="${code}-${section}"
        sub_folder_path="$cust_root/$sub_folder_name"

        if [[ ! -d "$sub_folder_path" ]]; then
            msg="MISSING subfolder $sub_folder_name for ${code}: $sub_folder_path"
            log_error "$msg"
            errors+=("$msg")
            continue
        else
            log_debug "Subfolder OK: $sub_folder_path"
        fi

        sub_index_path="$sub_folder_path/$sub_folder_name-Index.md"
        if [[ ! -f "$sub_index_path" ]]; then
            msg="MISSING subfolder index $sub_folder_name for ${code}: $sub_index_path"
            log_error "$msg"
        else
            log_debug "Subfolder index OK: $sub_index_path"
        fi
    done

    # Optional: hub contains link to CUST-XXX-Index
    if [[ -n "$hub_content" ]]; then
        expected_token="${code}-Index"
        if [[ "$hub_content" != *"$expected_token"* ]]; then
            msg="Hub file does not contain reference to $expected_token"
            log_warn "$msg"
            warnings+=("$msg")
        else
            log_debug "Hub contains reference to $expected_token"
        fi
    fi
done

if [[ ${#errors[@]} -eq 0 ]]; then
    if [[ ${#warnings[@]} -gt 0 ]]; then
        log_warn "VERIFICATION COMPLETE WITH WARNINGS – Review logged warnings."
        for warn in "${warnings[@]}"; do
            echo "  - $warn"
        done
    else
        log_info "VERIFICATION SUCCESS – Run structure and all CUST indexes are present."
    fi
    exit 0
else
    log_error "VERIFICATION FAILED – Issues detected:"
    for err in "${errors[@]}"; do
        echo "  - $err"
    done
    if [[ ${#warnings[@]} -gt 0 ]]; then
        log_warn "Additional warnings encountered:"
        for warn in "${warnings[@]}"; do
            echo "  - $warn"
        done
    fi
    exit 1
fi
