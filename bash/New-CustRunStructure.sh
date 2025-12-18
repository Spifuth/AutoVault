#!/usr/bin/env bash
#
# New-CustRunStructure.sh
#
# Creates the folder structure for customer runs in the Obsidian vault.
#
# STRUCTURE CREATED:
#   <VAULT_ROOT>/Run/
#       CUST-002/
#           CUST-002-Index.md
#           CUST-002-FP/
#               CUST-002-FP-Index.md
#           CUST-002-RAISED/
#               ...
#
#   And: <VAULT_ROOT>/Run-Hub.md
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared libraries
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/config.sh"

#######################################
# Helper functions
#######################################

ensure_directory() {
    local path="$1"
    if [[ ! -d "$path" ]]; then
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_info "[DRY-RUN] Would create directory: $path"
        else
            log_info "Creating directory: $path"
            mkdir -p "$path"
        fi
    else
        log_debug "Directory already exists: $path"
    fi
}

new_emptyfile_overwrite() {
    local path="$1"
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        if [[ -f "$path" ]]; then
            log_info "[DRY-RUN] Would overwrite file: $path"
        else
            log_info "[DRY-RUN] Would create file: $path"
        fi
    else
        if [[ -f "$path" ]]; then
            log_info "Overwriting file: $path"
        else
            log_info "Creating file: $path"
        fi
        # Create or truncate file
        : > "$path"
    fi
}

#######################################
# Main logic
#######################################

# Load configuration from JSON
if ! load_config; then
    log_error "Failed to load configuration. Aborting."
    exit 1
fi

log_info "Starting CUST Run structure creation"
log_info "Vault root: $VAULT_ROOT"

if [[ -z "${VAULT_ROOT:-}" ]]; then
    log_error "VAULT_ROOT is not set. Configure cust-run-config.sh or export VAULT_ROOT."
    exit 1
fi

if [[ ${#CUSTOMER_IDS[@]} -eq 0 ]]; then
    log_error "No CUST ids defined in CUSTOMER_IDS. Update cust-run-config.sh or export CUSTOMER_IDS."
    exit 1
fi

# Ensure vault root and Run folder exist
ensure_directory "$VAULT_ROOT"
RUN_PATH="$VAULT_ROOT/Run"
ensure_directory "$RUN_PATH"

# Prepare hub content lines (array)
hub_lines=()
hub_lines+=("# Run Hub")
hub_lines+=("")
hub_lines+=("## Customers")
hub_lines+=("")

for id in "${CUSTOMER_IDS[@]}"; do
    # Check integer
    if ! [[ "$id" =~ ^[0-9]+$ ]]; then
        log_error "Invalid CUST id (not an integer): $id"
        continue
    fi

    code="$(get_cust_code "$id")"
    log_info "Processing $code"

    # Root CUST folder: Run/CUST-XXX
    cust_root="$RUN_PATH/$code"
    ensure_directory "$cust_root"

    # Root index: CUST-XXX-Index.md
    cust_index_name="$code-Index.md"
    cust_index_path="$cust_root/$cust_index_name"
    new_emptyfile_overwrite "$cust_index_path"

    # Add link to hub (Obsidian wikilink syntax)
    # Relative path: Run/CUST-XXX/CUST-XXX-Index
    relative_target="Run/$code/$code-Index"
    hub_lines+=("- [[${relative_target}]]")

    # Subfolders and their index files
    for section in "${SECTIONS[@]}"; do
        sub_folder_name="${code}-${section}"
        sub_folder_path="$cust_root/$sub_folder_name"
        ensure_directory "$sub_folder_path"

        sub_index_name="${sub_folder_name}-Index.md"
        sub_index_path="$sub_folder_path/$sub_index_name"
        new_emptyfile_overwrite "$sub_index_path"
    done
done

# Write the Run-Hub.md file next to Run
hub_path="$VAULT_ROOT/Run-Hub.md"
if [[ -f "$hub_path" ]]; then
    log_info "Hub file already exists; preserving current content: $hub_path"
else
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY-RUN] Would create hub file: $hub_path"
    else
        printf "%s\n" "${hub_lines[@]}" > "$hub_path"
        log_info "Hub file written: $hub_path"
    fi
fi

log_info "CUST Run structure creation completed."
