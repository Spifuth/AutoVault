#!/usr/bin/env bash
#
# Generate-CustRunTemplates.sh
# Create markdown template files under the Vault _templates folder from a JSON spec.

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

TEMPLATE_ROOT="$VAULT_ROOT/${TEMPLATE_RELATIVE_ROOT##/}"
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

log "INFO" "Reading template definitions from: $TEMPLATE_SPEC_PATH"

count=0
while IFS= read -r -d '' name && IFS= read -r -d '' content; do
    if [[ -z "$name" ]]; then
        log "WARN" "Encountered template entry without FileName. Skipping."
        continue
    fi

    # Harden $name against path traversal and absolute path issues
    if [[ "$name" == /* ]]; then
        log "WARN" "Template FileName is an absolute path: '$name'. Skipping."
        continue
    fi
    if [[ "$name" == *../* || "$name" == *..\\* || "$name" == ../* || "$name" == ..\\* ]]; then
        log "WARN" "Template FileName contains parent directory traversal '..': '$name'. Skipping."
        continue
    fi

    target_path="$TEMPLATE_ROOT/$name"
    # Resolve full paths for comparison
    resolved_template_root="$(cd "$TEMPLATE_ROOT" && pwd -P)"
    resolved_target_path="$(mkdir -p "$(dirname "$target_path")" && cd "$(dirname "$target_path")" && pwd -P)/$(basename "$target_path")"
    if [[ "$resolved_target_path" != "$resolved_template_root"/* ]]; then
        log "WARN" "Template FileName escapes template root: '$name' -> '$resolved_target_path'. Skipping."
        continue
    fi

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
