#!/usr/bin/env bash
#===============================================================================
#
#  AUTOVAULT - Generate-CustRunTemplates.sh
#
#===============================================================================
#
#  DESCRIPTION:    Creates markdown template files under the vault's
#                  _templates folder from a JSON specification file.
#
#  INPUT FILE:     cust-run-templates.json (in project root or vault)
#                  Contains template content for each file type
#
#  OUTPUT:         Creates files in <VAULT_ROOT>/_templates/Run/:
#                  - CUST-Root-Index.md
#                  - CUST-Section-FP-Index.md
#                  - CUST-Section-RAISED-Index.md
#                  - etc.
#
#  USAGE:          ./Generate-CustRunTemplates.sh [JSON_FILE]
#                  ./Generate-CustRunTemplates.sh cust-run-templates.json
#
#  NOTE:           This is a standalone utility script.
#                  For template management, prefer using:
#                  ./cust-run-config.sh templates sync
#
#  DEPENDENCIES:   jq, python3 (optional for complex templates)
#
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SCRIPT="$SCRIPT_DIR/cust-run-config.sh"

log() {
    local level="${1:-INFO}"
    shift
    printf '[%s] %s\n' "$level" "$*"
}

if [[ -f "$CONFIG_SCRIPT" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_SCRIPT"

    if declare -F export_cust_env >/dev/null; then
        export_cust_env
    fi
fi

# Prefer values defined in cust-run-config.sh, with fallbacks to exported env vars
VAULT_ROOT="${VAULT_ROOT:-${CUST_VAULT_ROOT:-}}"
TEMPLATE_RELATIVE_ROOT="${TEMPLATE_RELATIVE_ROOT:-${CUST_TEMPLATE_RELATIVE_ROOT:-_templates/Run}}"
TEMPLATE_RELATIVE_ROOT="${TEMPLATE_RELATIVE_ROOT//\\//}"

if [[ -z "${VAULT_ROOT:-}" ]]; then
    log "ERROR" "VAULT_ROOT is not set. Run via cust-run-config.sh or update cust-run-config.sh."
    exit 1
fi

TEMPLATE_SPEC_PATH="${1:-$SCRIPT_DIR/cust-run-templates.json}"

if [[ ! -f "$TEMPLATE_SPEC_PATH" ]]; then
    log "ERROR" "Template JSON not found: $TEMPLATE_SPEC_PATH"
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    log "ERROR" "python3 is required to parse $TEMPLATE_SPEC_PATH"
    exit 1
fi

TEMPLATE_ROOT="$VAULT_ROOT/${TEMPLATE_RELATIVE_ROOT#/}"
log "INFO" "Writing templates to: $TEMPLATE_ROOT"
mkdir -p "$TEMPLATE_ROOT"

write_template() {
    local dest_path="$1"
    local content="$2"

    local dir
    dir="$(dirname "$dest_path")"
    if [[ ! -d "$dir" ]]; then
        log "INFO" "Creating directory: $dir"
        mkdir -p "$dir"
    fi

    printf "%s" "$content" > "$dest_path"
    log "INFO" "Template written: $dest_path"
}

validate_path() {
    local name="$1"
    local template_root="$2"

    # Reject absolute paths
    if [[ "$name" == /* ]]; then
        log "ERROR" "Rejected absolute path in FileName: $name"
        return 1
    fi

    # Reject paths containing ".." segments (path traversal)
    # Regex matches ".." only as a complete path component (bounded by / or start/end)
    # This allows legitimate filenames like "file..txt" while blocking "../" or "subdir/../"
    if [[ "$name" =~ (^|/)\.\.($|/) ]]; then
        log "ERROR" "Rejected path with '..' segments in FileName: $name"
        return 1
    fi

    # Construct the target path
    local target_path="$template_root/$name"

    # Resolve the real path (canonicalize) and verify it's still within TEMPLATE_ROOT
    local real_target
    real_target="$(realpath -m "$target_path")"
    local real_root
    real_root="$(realpath -m "$template_root")"

    # Check if the resolved path is under the template root
    if [[ "$real_target" != "$real_root"/* ]] && [[ "$real_target" != "$real_root" ]]; then
        log "ERROR" "Rejected path outside template root: $name (resolves to $real_target, expected under $real_root)"
        return 1
    fi

    return 0
}

log "INFO" "Reading template definitions from: $TEMPLATE_SPEC_PATH"

count=0
while IFS= read -r -d '' name && IFS= read -r -d '' content; do
    if [[ -z "$name" ]]; then
        log "WARN" "Encountered template entry without FileName. Skipping."
        continue
    fi

    # Validate the path before using it
    if ! validate_path "$name" "$TEMPLATE_ROOT"; then
        log "WARN" "Skipping invalid template path: $name"
        continue
    fi

    target_path="$TEMPLATE_ROOT/$name"
    write_template "$target_path" "$content"
    count=$((count + 1))
done < <(python3 - "$TEMPLATE_SPEC_PATH" <<'PY'
import json
import sys
from pathlib import Path

spec_path = Path(sys.argv[1])
with spec_path.open("r", encoding="utf-8") as fh:
    data = json.load(fh)

templates = data.get("Templates", [])
for tmpl in templates:
    name = tmpl.get("FileName", "")
    content = tmpl.get("Content", "")
    sys.stdout.write(name)
    sys.stdout.write("\0")
    sys.stdout.write(content)
    sys.stdout.write("\0")
PY
)

if [[ $count -eq 0 ]]; then
    log "WARN" "No templates were written. Check the JSON structure (expecting a 'Templates' array)."
else
    log "INFO" "Completed writing $count template(s)."
fi

exit 0
