#!/usr/bin/env bash
#
# New-CustRunStructure.sh
#
# CONFIGURATION:
#   - Configuration is sourced from cust-run-config.sh (or environment overrides).
#
# STRUCTURE CREATED:
#   <VAULT_ROOT>/Run/
#       CUST-002/
#           CUST-002-FP/
#               CUST-002-FP-Index.md
#           CUST-002-RAISED/
#               CUST-002-RAISED-Index.md
#           CUST-002-INFORMATIONS/
#               CUST-002-INFORMATIONS-Index.md
#           CUST-002-DIVERS/
#               CUST-002-DIVERS-Index.md
#
#   And next to the Run folder:
#   <VAULT_ROOT>/Run-Hub.md
#       -> contains links to each CUST root index (CUST-002-Index, etc.)
#
# NAMING RULES:
#   - Customer code       : CUST-XXX   (zero-padded with width = CUSTOMER_ID_WIDTH)
#   - Customer folder     : Run/CUST-XXX
#   - Root index file     : Run/CUST-XXX/CUST-XXX-Index.md
#   - Subfolders          : CUST-XXX-FP, CUST-XXX-RAISED, CUST-XXX-INFORMATIONS, CUST-XXX-DIVERS
#   - Subfolder index file: <SubFolderName>-Index.md
#

#######################################
# Configuration
#######################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SCRIPT="$SCRIPT_DIR/cust-run-config.sh"

#######################################
# Load shared config / environment
#######################################

load_config() {
    if [[ -f "$CONFIG_SCRIPT" ]]; then
        write_log "INFO" "Loading configuration from $CONFIG_SCRIPT"
        if ! source "$CONFIG_SCRIPT"; then
            write_log "ERROR" "Failed to load configuration from $CONFIG_SCRIPT"
        fi
    else
        write_log "WARN" "Configuration script not found at $CONFIG_SCRIPT; falling back to environment variables"
    fi

    if declare -F export_cust_env >/dev/null 2>&1; then
        export_cust_env
    fi

    if [[ -z "${VAULT_ROOT:-}" && -n "${CUST_VAULT_ROOT:-}" ]]; then
        VAULT_ROOT="$CUST_VAULT_ROOT"
    fi

    if [[ -z "${CUSTOMER_ID_WIDTH:-}" && -n "${CUST_CUSTOMER_ID_WIDTH:-}" ]]; then
        CUSTOMER_ID_WIDTH="$CUST_CUSTOMER_ID_WIDTH"
    fi

    if [[ ${#CUSTOMER_IDS[@]:-0} -eq 0 && -n "${CUST_CUSTOMER_IDS:-}" ]]; then
        read -r -a CUSTOMER_IDS <<<"$CUST_CUSTOMER_IDS"
    fi

    local sections_env="${CUST_SECTIONS:-}"
    if [[ ${#CUST_SECTIONS[@]:-0} -eq 0 && -n "$sections_env" ]]; then
        read -r -a CUST_SECTIONS <<<"$sections_env"
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
}

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

ensure_directory() {
    local path="$1"
    if [[ ! -d "$path" ]]; then
        write_log "INFO" "Creating directory: $path"
        mkdir -p "$path"
    else
        write_log "DEBUG" "Directory already exists: $path"
    fi
}

new_emptyfile_overwrite() {
    local path="$1"
    if [[ -f "$path" ]]; then
        write_log "INFO" "Overwriting file: $path"
    else
        write_log "INFO" "Creating file: $path"
    fi
    # Create or truncate file
    : > "$path"
}

get_cust_code() {
    local id="$1"
    # zero-pad with CUSTOMER_ID_WIDTH
    printf "CUST-%0${CUSTOMER_ID_WIDTH}d" "$id"
}

#######################################
# Main logic
#######################################

load_config

write_log "INFO" "Starting CUST Run structure creation"
write_log "INFO" "Vault root: $VAULT_ROOT"

if [[ -z "${VAULT_ROOT:-}" ]]; then
    write_log "ERROR" "VAULT_ROOT is not set. Configure cust-run-config.sh or export VAULT_ROOT."
    exit 1
fi

if [[ ${#CUSTOMER_IDS[@]} -eq 0 ]]; then
    write_log "ERROR" "No CUST ids defined in CUSTOMER_IDS. Update cust-run-config.sh or export CUSTOMER_IDS."
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
        write_log "ERROR" "Invalid CUST id (not an integer): $id"
        continue
    fi

    code="$(get_cust_code "$id")"
    write_log "INFO" "Processing $code"

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
    for section in "${CUST_SECTIONS[@]}"; do
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
printf "%s\n" "${hub_lines[@]}" > "$hub_path"
write_log "INFO" "Hub file written: $hub_path"

write_log "INFO" "CUST Run structure creation completed."
