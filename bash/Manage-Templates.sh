#!/usr/bin/env bash
#
# Manage-Templates.sh
#
# Manage templates: export from vault, sync to vault, apply to CUST folders
#
# Commands:
#   export  - Read templates from vault/_templates/ and update config/templates.json
#   sync    - Write templates from config/templates.json to vault/_templates/
#   apply   - Apply templates to CUST folders (replace placeholders)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared libraries
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/config.sh"

# Templates JSON file
TEMPLATES_JSON="${TEMPLATES_JSON:-"$SCRIPT_DIR/../config/templates.json"}"

# Load configuration
if ! load_config; then
    log_error "Failed to load configuration"
    exit 1
fi

# Normalize paths
VAULT_ROOT="${VAULT_ROOT/#\~/$HOME}"
if [[ "$VAULT_ROOT" == *"\\"* ]]; then
    VAULT_ROOT="${VAULT_ROOT//\\//}"
fi

TEMPLATE_RELATIVE_ROOT="${TEMPLATE_RELATIVE_ROOT//\\//}"

#######################################
# Helper: Get template folder in vault
#######################################
get_vault_template_dir() {
    echo "$VAULT_ROOT/${TEMPLATE_RELATIVE_ROOT#/}"
}

#######################################
# Helper: Read file content and escape for JSON
#######################################
file_to_json_string() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo ""
        return
    fi
    # Use python for proper JSON escaping
    python3 -c "
import json
import sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    content = f.read()
print(json.dumps(content)[1:-1])  # Remove surrounding quotes
" "$file"
}

#######################################
# Helper: Write JSON string to file
#######################################
json_string_to_file() {
    local json_string="$1"
    local file="$2"
    
    local dir
    dir="$(dirname "$file")"
    
    if [[ ! -d "$dir" ]]; then
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_info "[DRY-RUN] Would create directory: $dir"
        else
            mkdir -p "$dir"
            log_debug "Created directory: $dir"
        fi
    fi
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY-RUN] Would write template to: $file"
    else
        # Use python to decode JSON string and write to file
        python3 -c "
import json
import sys

json_str = sys.argv[1]
file_path = sys.argv[2]

# The string is already unescaped from jq, just write it
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(json_str)
" "$json_string" "$file"
        log_info "Template written: $file"
    fi
}

#######################################
# EXPORT: Read templates from vault and update JSON
#######################################
cmd_export() {
    local template_dir
    template_dir="$(get_vault_template_dir)"
    
    log_info "Exporting templates from: $template_dir"
    
    if [[ ! -d "$template_dir" ]]; then
        log_error "Template directory does not exist: $template_dir"
        return 1
    fi
    
    # Check required files exist
    local root_tpl="$template_dir/CUST-Root-Index.md"
    if [[ ! -f "$root_tpl" ]]; then
        log_error "Root template not found: $root_tpl"
        return 1
    fi
    
    # Build JSON using python
    python3 - "$template_dir" "$TEMPLATES_JSON" "$TEMPLATE_RELATIVE_ROOT" <<'PYTHON'
import json
import sys
import os
from pathlib import Path

template_dir = Path(sys.argv[1])
output_file = sys.argv[2]
template_folder = sys.argv[3]

def read_file(path):
    if path.exists():
        return path.read_text(encoding='utf-8')
    return ""

# Read all templates
templates = {
    "version": "1.0",
    "description": "AutoVault templates for CUST Run structure",
    "obsidian": {
        "templateFolder": template_folder
    },
    "templates": {
        "index": {
            "root": read_file(template_dir / "CUST-Root-Index.md"),
            "sections": {
                "FP": read_file(template_dir / "CUST-Section-FP-Index.md"),
                "RAISED": read_file(template_dir / "CUST-Section-RAISED-Index.md"),
                "INFORMATIONS": read_file(template_dir / "CUST-Section-INFORMATIONS-Index.md"),
                "DIVERS": read_file(template_dir / "CUST-Section-DIVERS-Index.md")
            }
        },
        "notes": {
            "FP": read_file(template_dir / "RUN - New FP note.md"),
            "RAISED": read_file(template_dir / "RUN - New RAISED note.md"),
            "INFORMATIONS": read_file(template_dir / "RUN - New INFORMATIONS note.md"),
            "DIVERS": read_file(template_dir / "RUN - New DIVERS note.md")
        }
    }
}

# Write JSON
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(templates, f, indent=2, ensure_ascii=False)

print(f"Exported templates to: {output_file}")
PYTHON

    log_success "Templates exported to: $TEMPLATES_JSON"
}

#######################################
# SYNC: Write templates from JSON to vault
#######################################
cmd_sync() {
    local template_dir
    template_dir="$(get_vault_template_dir)"
    
    log_info "Syncing templates to: $template_dir"
    
    if [[ ! -f "$TEMPLATES_JSON" ]]; then
        log_error "Templates JSON not found: $TEMPLATES_JSON"
        return 1
    fi
    
    # Create template directory if needed
    if [[ ! -d "$template_dir" ]]; then
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_info "[DRY-RUN] Would create directory: $template_dir"
        else
            mkdir -p "$template_dir"
            log_info "Created template directory: $template_dir"
        fi
    fi
    
    # Write templates using python
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        python3 - "$TEMPLATES_JSON" "$template_dir" "true" <<'PYTHON'
import json
import sys
from pathlib import Path

templates_file = sys.argv[1]
template_dir = Path(sys.argv[2])
dry_run = sys.argv[3] == "true"

with open(templates_file, 'r', encoding='utf-8') as f:
    data = json.load(f)

templates = data.get("templates", {})

# Index templates
index = templates.get("index", {})
files_to_write = [
    ("CUST-Root-Index.md", index.get("root", "")),
]

for section, content in index.get("sections", {}).items():
    files_to_write.append((f"CUST-Section-{section}-Index.md", content))

# Note templates
notes = templates.get("notes", {})
for section, content in notes.items():
    files_to_write.append((f"RUN - New {section} note.md", content))

for filename, content in files_to_write:
    filepath = template_dir / filename
    if dry_run:
        print(f"[DRY-RUN] Would write: {filepath}")
    else:
        filepath.write_text(content, encoding='utf-8')
        print(f"Written: {filepath}")
PYTHON
    else
        python3 - "$TEMPLATES_JSON" "$template_dir" "false" <<'PYTHON'
import json
import sys
from pathlib import Path

templates_file = sys.argv[1]
template_dir = Path(sys.argv[2])
dry_run = sys.argv[3] == "true"

with open(templates_file, 'r', encoding='utf-8') as f:
    data = json.load(f)

templates = data.get("templates", {})

# Index templates
index = templates.get("index", {})
files_to_write = [
    ("CUST-Root-Index.md", index.get("root", "")),
]

for section, content in index.get("sections", {}).items():
    files_to_write.append((f"CUST-Section-{section}-Index.md", content))

# Note templates
notes = templates.get("notes", {})
for section, content in notes.items():
    files_to_write.append((f"RUN - New {section} note.md", content))

for filename, content in files_to_write:
    filepath = template_dir / filename
    if dry_run:
        print(f"[DRY-RUN] Would write: {filepath}")
    else:
        filepath.write_text(content, encoding='utf-8')
        print(f"Written: {filepath}")
PYTHON
    fi
    
    log_success "Templates synced to: $template_dir"
}

#######################################
# APPLY: Apply templates to CUST folders
#######################################
cmd_apply() {
    log_info "Applying templates to CUST folders"
    
    if [[ ! -f "$TEMPLATES_JSON" ]]; then
        log_error "Templates JSON not found: $TEMPLATES_JSON"
        return 1
    fi
    
    local run_dir="$VAULT_ROOT/Run"
    
    if [[ ! -d "$run_dir" ]]; then
        log_error "Run directory does not exist: $run_dir"
        log_info "Run 'structure' command first to create the folder structure."
        return 1
    fi
    
    # Apply templates using python
    python3 - "$TEMPLATES_JSON" "$run_dir" "${CUSTOMER_IDS[*]}" "$CUSTOMER_ID_WIDTH" "${SECTIONS[*]}" "${DRY_RUN:-false}" <<'PYTHON'
import json
import sys
from pathlib import Path
from datetime import datetime, timezone

templates_file = sys.argv[1]
run_dir = Path(sys.argv[2])
customer_ids = [int(x) for x in sys.argv[3].split()]
customer_id_width = int(sys.argv[4])
sections = sys.argv[5].split()
dry_run = sys.argv[6] == "true"

with open(templates_file, 'r', encoding='utf-8') as f:
    data = json.load(f)

templates = data.get("templates", {})
index_templates = templates.get("index", {})
root_template = index_templates.get("root", "")
section_templates = index_templates.get("sections", {})

def get_cust_code(cust_id):
    return f"CUST-{cust_id:0{customer_id_width}d}"

def replace_placeholders(content, cust_code):
    now_utc = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    now_local = datetime.now().strftime("%Y-%m-%dT%H:%M:%S%z")
    
    result = content.replace("{{CUST_CODE}}", cust_code)
    result = result.replace("{{NOW_UTC}}", now_utc)
    result = result.replace("{{NOW_LOCAL}}", now_local)
    return result

def write_file(path, content):
    if dry_run:
        print(f"[DRY-RUN] Would apply template to: {path}")
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding='utf-8')
        print(f"Template applied to: {path}")

for cust_id in customer_ids:
    cust_code = get_cust_code(cust_id)
    cust_dir = run_dir / cust_code
    
    # Root index
    root_content = replace_placeholders(root_template, cust_code)
    root_file = cust_dir / f"{cust_code}-Index.md"
    write_file(root_file, root_content)
    
    # Section indexes
    for section in sections:
        section_template = section_templates.get(section, "")
        if section_template:
            section_content = replace_placeholders(section_template, cust_code)
            section_dir = cust_dir / f"{cust_code}-{section}"
            section_file = section_dir / f"{cust_code}-{section}-Index.md"
            write_file(section_file, section_content)

print("Template application completed.")
PYTHON

    log_success "Templates applied to all CUST folders"
}

#######################################
# Main
#######################################
show_usage() {
    cat <<EOF
Usage: $(basename "$0") COMMAND

Commands:
  export    Read templates from vault/_templates/ and update config/templates.json
  sync      Write templates from config/templates.json to vault/_templates/
  apply     Apply templates to CUST folders (replace placeholders)

Environment:
  DRY_RUN=true    Show what would be done without making changes
EOF
}

case "${1:-}" in
    export)
        cmd_export
        ;;
    sync)
        cmd_sync
        ;;
    apply)
        cmd_apply
        ;;
    -h|--help|help)
        show_usage
        ;;
    *)
        log_error "Unknown command: ${1:-}"
        show_usage
        exit 1
        ;;
esac
