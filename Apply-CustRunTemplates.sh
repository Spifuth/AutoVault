#!/usr/bin/env bash
#
# Apply-CustRunTemplates.sh
#
# APPLY EXTERNAL MARKDOWN TEMPLATES TO ALL CUST RUN INDEX FILES
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

# Template locations (relative to VAULT_ROOT)
TEMPLATE_ROOT="$VAULT_ROOT/_templates/Run"
ROOT_TEMPLATE_PATH="$TEMPLATE_ROOT/CUST-Root-Index.md"

# Associative array for section templates
declare -A SECTION_TEMPLATE_PATHS=(
    ["FP"]="$TEMPLATE_ROOT/CUST-Section-FP-Index.md"
    ["RAISED"]="$TEMPLATE_ROOT/CUST-Section-RAISED-Index.md"
    ["INFORMATIONS"]="$TEMPLATE_ROOT/CUST-Section-INFORMATIONS-Index.md"
    ["DIVERS"]="$TEMPLATE_ROOT/CUST-Section-DIVERS-Index.md"
)

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

get_template_content() {
    local path="$1"
    local logical_name="$2"

    if [[ ! -f "$path" ]]; then
        write_log "ERROR" "Template missing for ${logical_name}: ${path}"
        return 1
    fi

    cat "$path"
}

set_file_content() {
    local path="$1"
    local content="$2"

    local dir
    dir="$(dirname "$path")"

    if [[ ! -d "$dir" ]]; then
        write_log "WARN" "Target directory does not exist, creating: $dir"
        mkdir -p "$dir"
    fi

    # Écrit exactement le contenu (sans rajouter de newline parasite)
    printf "%s" "$content" > "$path"
    write_log "INFO" "Template applied to: $path"
}

#######################################
# Load templates
#######################################

write_log "INFO" "Loading templates from: $TEMPLATE_ROOT"

root_template_content="$(get_template_content "$ROOT_TEMPLATE_PATH" "ROOT")"
if [[ $? -ne 0 ]]; then
    write_log "ERROR" "Aborting: root template missing."
    exit 1
fi

declare -A SECTION_TEMPLATE_CONTENT

for section in "${SECTIONS[@]}"; do
    tmpl_path="${SECTION_TEMPLATE_PATHS[$section]}"
    if [[ -z "$tmpl_path" ]]; then
        write_log "ERROR" "No template mapping defined for section '$section'."
        exit 1
    fi

    content="$(get_template_content "$tmpl_path" "$section")"
    if [[ $? -ne 0 ]]; then
        write_log "ERROR" "Aborting: template missing for section '$section'."
        exit 1
    fi

    SECTION_TEMPLATE_CONTENT["$section"]="$content"
done

#######################################
# Apply templates
#######################################

if [[ ${#CUSTOMER_IDS[@]} -eq 0 ]]; then
    write_log "ERROR" "No CUST ids defined in CUSTOMER_IDS. Edit the configuration at the top of the script."
    exit 1
fi

RUN_PATH="$VAULT_ROOT/Run"

for id in "${CUSTOMER_IDS[@]}"; do
    if ! [[ "$id" =~ ^[0-9]+$ ]]; then
        write_log "ERROR" "Invalid CUST id (not an integer): $id"
        continue
    fi

    code="$(get_cust_code "$id")"
    cust_root="$RUN_PATH/$code"

    if [[ ! -d "$cust_root" ]]; then
        write_log "WARN" "CUST folder missing, skipping ${code}: $cust_root"
        continue
    fi

    # Contexte commun
    now_utc="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    now_local="$(date +"%Y-%m-%dT%H:%M:%S%z")"

    #######################################
    # Root index
    #######################################
    root_index_path="$cust_root/$code-Index.md"
    if [[ ! -f "$root_index_path" ]]; then
        write_log "WARN" "Root index does not exist yet, will create: $root_index_path"
    fi

    root_content="$root_template_content"
    root_content="${root_content//\{\{CUST_CODE\}\}/$code}"
    root_content="${root_content//\{\{NOW_UTC\}\}/$now_utc}"
    root_content="${root_content//\{\{NOW_LOCAL\}\}/$now_local}"

    # SECTION n'existe pas dans le root template normalement, mais au cas où:
    root_content="${root_content//\{\{SECTION\}\}/}"

    set_file_content "$root_index_path" "$root_content"

    #######################################
    # Section indexes
    #######################################
    for section in "${SECTIONS[@]}"; do
        sub_folder_name="${code}-${section}"
        sub_folder_path="$cust_root/$sub_folder_name"

        if [[ ! -d "$sub_folder_path" ]]; then
            write_log "WARN" "Subfolder missing for ${code} ($section), skipping: $sub_folder_path"
            continue
        fi

        sub_index_path="$sub_folder_path/$sub_folder_name-Index.md"
        if [[ ! -f "$sub_index_path" ]]; then
            write_log "WARN" "Subfolder index does not exist yet for ${code} ($section), will create: $sub_index_path"
        fi

        tmpl_text="${SECTION_TEMPLATE_CONTENT[$section]}"

        sect_content="$tmpl_text"
        sect_content="${sect_content//\{\{CUST_CODE\}\}/$code}"
        sect_content="${sect_content//\{\{SECTION\}\}/$section}"
        sect_content="${sect_content//\{\{NOW_UTC\}\}/$now_utc}"
        sect_content="${sect_content//\{\{NOW_LOCAL\}\}/$now_local}"

        set_file_content "$sub_index_path" "$sect_content"
    done
done

write_log "INFO" "Template application completed."
exit 0
