#!/usr/bin/env bash
#===============================================================================
#
#  AUTOVAULT - Apply-CustRunTemplates.sh
#
#===============================================================================
#
#  DESCRIPTION:    Applies external markdown templates to all CUST Run
#                  index files. Reads templates from the vault's _templates
#                  folder and writes them to each customer's index files.
#
#  TEMPLATES APPLIED:
#                  - CUST-XXX-Index.md         (from CUST-Root-Index.md)
#                  - CUST-XXX-SECTION-Index.md (from CUST-Section-SECTION-Index.md)
#
#  PLACEHOLDERS REPLACED:
#                  {{CUST_CODE}}  -> Customer code (e.g., CUST-001)
#                  {{SECTION}}    -> Section name (e.g., FP, RAISED)
#                  {{NOW_UTC}}    -> Current UTC timestamp
#                  {{NOW_LOCAL}}  -> Current local timestamp
#
#  NOTE:           This is a legacy script. Prefer using Manage-Templates.sh
#                  which reads from config/templates.json instead.
#
#  USAGE:          bash/Apply-CustRunTemplates.sh
#
#  DEPENDENCIES:   bash/lib/logging.sh, bash/lib/config.sh
#
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared libraries
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/config.sh"

# DEPRECATION WARNING
log_warn "================================================================"
log_warn "DEPRECATED: Apply-CustRunTemplates.sh is a legacy script"
log_warn "Please use: cust-run-config.sh templates apply"
log_warn "This script reads from vault templates, not config/templates.json"
log_warn "================================================================"
echo ""

# Load configuration
if ! load_config; then
    log_error "Failed to load configuration"
    exit 1
fi

# Normalize VAULT_ROOT path
VAULT_ROOT="${VAULT_ROOT/#\~/$HOME}"
if [[ "$VAULT_ROOT" == *"\\"* ]]; then
    VAULT_ROOT="${VAULT_ROOT//\\//}"
fi

# Normalize template path (convert Windows-style separators)
TEMPLATE_RELATIVE_ROOT="${TEMPLATE_RELATIVE_ROOT//\\//}"
TEMPLATE_ROOT="$VAULT_ROOT/${TEMPLATE_RELATIVE_ROOT#/}"
ROOT_TEMPLATE_PATH="$TEMPLATE_ROOT/CUST-Root-Index.md"

# Function to get section template path dynamically
get_section_template_path() {
    local section="$1"
    echo "$TEMPLATE_ROOT/CUST-Section-${section}-Index.md"
}

#######################################
# Helper functions
#######################################

get_template_content() {
    local path="$1"
    local logical_name="$2"

    if [[ ! -f "$path" ]]; then
        log_error "Template missing for ${logical_name}: ${path}"
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
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_warn "[DRY-RUN] Would create directory: $dir"
        else
            log_warn "Target directory does not exist, creating: $dir"
            mkdir -p "$dir"
        fi
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY-RUN] Would apply template to: $path"
    else
        # Écrit exactement le contenu (sans rajouter de newline parasite)
        printf "%s" "$content" > "$path"
        log_info "Template applied to: $path"
    fi
}

#######################################
# Load templates
#######################################

log_info "Loading templates from: $TEMPLATE_ROOT"

if ! root_template_content="$(get_template_content "$ROOT_TEMPLATE_PATH" "ROOT")"; then
    log_error "Aborting: root template missing."
    exit 1
fi

declare -A SECTION_TEMPLATE_CONTENT

for section in "${SECTIONS[@]}"; do
    tmpl_path="$(get_section_template_path "$section")"

    if ! content="$(get_template_content "$tmpl_path" "$section")"; then
        log_error "Aborting: template missing for section '$section'."
        exit 1
    fi

    SECTION_TEMPLATE_CONTENT["$section"]="$content"
done

#######################################
# Apply templates
#######################################

if [[ ${#CUSTOMER_IDS[@]} -eq 0 ]]; then
    log_error "No CUST ids defined in CUSTOMER_IDS. Edit the configuration at the top of the script."
    exit 1
fi

RUN_PATH="$VAULT_ROOT/Run"

for id in "${CUSTOMER_IDS[@]}"; do
    if ! [[ "$id" =~ ^[0-9]+$ ]]; then
        log_error "Invalid CUST id (not an integer): $id"
        continue
    fi

    code="$(get_cust_code "$id")"
    cust_root="$RUN_PATH/$code"

    if [[ ! -d "$cust_root" ]]; then
        log_warn "CUST folder missing, skipping ${code}: $cust_root"
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
        log_warn "Root index does not exist yet, will create: $root_index_path"
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
            log_warn "Subfolder missing for ${code} ($section), skipping: $sub_folder_path"
            continue
        fi

        sub_index_path="$sub_folder_path/$sub_folder_name-Index.md"
        if [[ ! -f "$sub_index_path" ]]; then
            log_warn "Subfolder index does not exist yet for ${code} ($section), will create: $sub_index_path"
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

log_info "Template application completed."
exit 0
