#!/usr/bin/env bash
#
# Configure-ObsidianPlugins.sh
#
# Configure Obsidian plugins (Templater, Dataview) and settings
# by writing to the vault's .obsidian/ directory.
#
# Commands:
#   plugins   - Configure all plugin settings
#   check     - Check if plugins are installed
#   init      - Full vault initialization (structure + templates + plugins)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared libraries
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/config.sh"

# Obsidian settings JSON
OBSIDIAN_SETTINGS_JSON="${OBSIDIAN_SETTINGS_JSON:-"$SCRIPT_DIR/../config/obsidian-settings.json"}"
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

OBSIDIAN_DIR="$VAULT_ROOT/.obsidian"
PLUGINS_DIR="$OBSIDIAN_DIR/plugins"

#######################################
# Helper: Ensure .obsidian directory exists
#######################################
ensure_obsidian_dir() {
    if [[ ! -d "$OBSIDIAN_DIR" ]]; then
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_info "[DRY-RUN] Would create: $OBSIDIAN_DIR"
        else
            mkdir -p "$OBSIDIAN_DIR"
            log_info "Created: $OBSIDIAN_DIR"
        fi
    fi
}

#######################################
# Helper: Write JSON to file
#######################################
write_json_file() {
    local file="$1"
    local content="$2"
    local description="$3"
    
    local dir
    dir="$(dirname "$file")"
    
    if [[ ! -d "$dir" ]]; then
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_info "[DRY-RUN] Would create directory: $dir"
        else
            mkdir -p "$dir"
        fi
    fi
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY-RUN] Would write $description: $file"
    else
        echo "$content" > "$file"
        log_info "Configured $description: $file"
    fi
}

#######################################
# CHECK: Verify plugins are installed
#######################################
cmd_check() {
    log_info "Checking Obsidian plugins installation..."
    
    local all_ok=true
    
    # Check .obsidian directory
    if [[ ! -d "$OBSIDIAN_DIR" ]]; then
        log_warn "Obsidian directory not found: $OBSIDIAN_DIR"
        log_info "Please open the vault in Obsidian first to initialize it."
        return 1
    fi
    
    # Check Templater
    local templater_dir="$PLUGINS_DIR/templater-obsidian"
    if [[ -d "$templater_dir" ]]; then
        log_info "✓ Templater plugin found"
    else
        log_warn "✗ Templater plugin not installed"
        log_info "  Install from: Community Plugins → Browse → 'Templater'"
        all_ok=false
    fi
    
    # Check Dataview
    local dataview_dir="$PLUGINS_DIR/dataview"
    if [[ -d "$dataview_dir" ]]; then
        log_info "✓ Dataview plugin found"
    else
        log_warn "✗ Dataview plugin not installed"
        log_info "  Install from: Community Plugins → Browse → 'Dataview'"
        all_ok=false
    fi
    
    if [[ "$all_ok" == "true" ]]; then
        log_success "All required plugins are installed"
        return 0
    else
        log_warn "Some plugins are missing. Install them in Obsidian first."
        return 1
    fi
}

#######################################
# PLUGINS: Configure all plugin settings
#######################################
cmd_plugins() {
    log_info "Configuring Obsidian plugins..."
    
    if [[ ! -f "$OBSIDIAN_SETTINGS_JSON" ]]; then
        log_error "Obsidian settings file not found: $OBSIDIAN_SETTINGS_JSON"
        return 1
    fi
    
    ensure_obsidian_dir
    
    # Generate configurations using Python
    python3 - "$OBSIDIAN_SETTINGS_JSON" "$OBSIDIAN_DIR" "$PLUGINS_DIR" "${SECTIONS[*]}" "${DRY_RUN:-false}" <<'PYTHON'
import json
import sys
from pathlib import Path

settings_file = sys.argv[1]
obsidian_dir = Path(sys.argv[2])
plugins_dir = Path(sys.argv[3])
sections = sys.argv[4].split()
dry_run = sys.argv[5] == "true"

with open(settings_file, 'r', encoding='utf-8') as f:
    settings = json.load(f)

def write_file(path, content, description):
    if dry_run:
        print(f"[DRY-RUN] Would write {description}: {path}")
    else:
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(content, f, indent=2)
        print(f"Configured {description}: {path}")

# 1. Configure Templater
templater_settings = settings.get("templater", {})
templater_data = {
    "templates_folder": templater_settings.get("templates_folder", "_templates"),
    "templates_pairs": templater_settings.get("templates_pairs", []),
    "trigger_on_file_creation": templater_settings.get("trigger_on_file_creation", True),
    "auto_jump_to_cursor": templater_settings.get("auto_jump_to_cursor", True),
    "enable_system_commands": templater_settings.get("enable_system_commands", False),
    "shell_path": templater_settings.get("shell_path", ""),
    "user_scripts_folder": templater_settings.get("user_scripts_folder", ""),
    "enable_folder_templates": templater_settings.get("enable_folder_templates", True),
    "folder_templates": templater_settings.get("folder_templates", []),
    "syntax_highlighting": templater_settings.get("syntax_highlighting", True),
    "enabled_templates_hotkey_file_creation": templater_settings.get("enabled_templates_hotkey_file_creation", [])
}
templater_path = plugins_dir / "templater-obsidian" / "data.json"
write_file(templater_path, templater_data, "Templater")

# 2. Configure Dataview
dataview_settings = settings.get("dataview", {})
dataview_path = plugins_dir / "dataview" / "data.json"
write_file(dataview_path, dataview_settings, "Dataview")

# 3. Configure Bookmarks
bookmarks_settings = settings.get("bookmarks", {})
bookmarks_path = obsidian_dir / "bookmarks.json"
write_file(bookmarks_path, bookmarks_settings, "Bookmarks")

# 4. Configure Hotkeys (merge with existing if present)
hotkeys_settings = settings.get("hotkeys", {})
hotkeys_path = obsidian_dir / "hotkeys.json"
existing_hotkeys = {}
if hotkeys_path.exists() and not dry_run:
    try:
        with open(hotkeys_path, 'r', encoding='utf-8') as f:
            existing_hotkeys = json.load(f)
    except:
        pass
merged_hotkeys = {**existing_hotkeys, **hotkeys_settings}
write_file(hotkeys_path, merged_hotkeys, "Hotkeys")

# 5. Configure App settings (merge with existing)
app_settings = settings.get("app", {})
app_path = obsidian_dir / "app.json"
existing_app = {}
if app_path.exists() and not dry_run:
    try:
        with open(app_path, 'r', encoding='utf-8') as f:
            existing_app = json.load(f)
    except:
        pass
merged_app = {**existing_app, **app_settings}
write_file(app_path, merged_app, "App settings")

# 6. Ensure community plugins are enabled
community_plugins_path = obsidian_dir / "community-plugins.json"
plugins_to_enable = ["templater-obsidian", "dataview"]
existing_plugins = []
if community_plugins_path.exists() and not dry_run:
    try:
        with open(community_plugins_path, 'r', encoding='utf-8') as f:
            existing_plugins = json.load(f)
    except:
        pass
# Merge without duplicates
for plugin in plugins_to_enable:
    if plugin not in existing_plugins:
        existing_plugins.append(plugin)
write_file(community_plugins_path, existing_plugins, "Community plugins list")

print("Plugin configuration completed.")
PYTHON

    log_success "Obsidian plugins configured"
    log_info "Restart Obsidian to apply changes."
}

#######################################
# INIT: Full vault initialization
#######################################
cmd_init() {
    log_info "Initializing vault with full AutoVault setup..."
    
    # Check vault exists
    if [[ ! -d "$VAULT_ROOT" ]]; then
        log_error "Vault directory does not exist: $VAULT_ROOT"
        log_info "Please create the vault in Obsidian first, then run this command."
        return 1
    fi
    
    local errors=0
    
    # Step 1: Create structure
    log_info "Step 1/4: Creating folder structure..."
    if ! bash "$SCRIPT_DIR/New-CustRunStructure.sh"; then
        log_error "Failed to create structure"
        ((errors++))
    fi
    
    # Step 2: Sync templates to vault
    log_info "Step 2/4: Syncing templates to vault..."
    if ! bash "$SCRIPT_DIR/Manage-Templates.sh" sync; then
        log_error "Failed to sync templates"
        ((errors++))
    fi
    
    # Step 3: Apply templates to CUST folders
    log_info "Step 3/4: Applying templates to CUST folders..."
    if ! bash "$SCRIPT_DIR/Manage-Templates.sh" apply; then
        log_error "Failed to apply templates"
        ((errors++))
    fi
    
    # Step 4: Configure plugins
    log_info "Step 4/4: Configuring Obsidian plugins..."
    if ! cmd_plugins; then
        log_warn "Plugin configuration had warnings (plugins may not be installed yet)"
    fi
    
    echo ""
    if [[ $errors -eq 0 ]]; then
        log_success "Vault initialization completed successfully!"
        echo ""
        log_info "Next steps:"
        log_info "  1. Open the vault in Obsidian"
        log_info "  2. Install plugins if not already: Templater, Dataview"
        log_info "  3. Enable the plugins in Settings → Community plugins"
        log_info "  4. Restart Obsidian to apply all settings"
    else
        log_error "Vault initialization completed with $errors error(s)"
        return 1
    fi
}

#######################################
# HUB: Generate enhanced Run-Hub.md with Dataview
#######################################
cmd_hub() {
    log_info "Generating enhanced Run-Hub.md with Dataview queries..."
    
    local hub_file="$VAULT_ROOT/Run-Hub.md"
    
    # Generate hub content
    local hub_content
    hub_content=$(python3 - "${CUSTOMER_IDS[*]}" "$CUSTOMER_ID_WIDTH" "${SECTIONS[*]}" <<'PYTHON'
import sys
from datetime import datetime, timezone

customer_ids = [int(x) for x in sys.argv[1].split()]
customer_id_width = int(sys.argv[2])
sections = sys.argv[3].split()

now_utc = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
now_local = datetime.now().strftime("%Y-%m-%dT%H:%M:%S%z")

def get_cust_code(cust_id):
    return f"CUST-{cust_id:0{customer_id_width}d}"

# Build customer links
customer_links = []
for cust_id in customer_ids:
    cust_code = get_cust_code(cust_id)
    customer_links.append(f"- [[Run/{cust_code}/{cust_code}-Index|{cust_code}]]")

hub = f'''---
title: "Run Hub"
created_utc: "{now_utc}"
created_local: "{now_local}"
type: "hub"
tags:
  - run
  - hub
  - index
---

# 🏠 Run Hub

> Central navigation hub for all CUST Run operations.

---

## 📊 Dashboard

### Open Incidents (RAISED)

```dataview
TABLE WITHOUT ID
  file.link as "Incident",
  cust_code as "Customer",
  severity as "Severity",
  status as "Status",
  started_local as "Started"
FROM "Run"
WHERE type = "cust-run-raised-note" AND status != "Closed"
SORT severity DESC, started_utc DESC
```

### Recent Activity

```dataview
TABLE WITHOUT ID
  file.link as "Note",
  file.folder as "Location",
  file.mtime as "Modified"
FROM "Run"
WHERE type
SORT file.mtime DESC
LIMIT 10
```

---

## 🗂️ Customers ({len(customer_ids)})

{chr(10).join(customer_links)}

---

## 📁 Sections

| Section | Description |
|---------|-------------|
| **FP** | First Pass - routine checks and triage patterns |
| **RAISED** | Incidents and tickets raised |
| **INFORMATIONS** | Knowledge base and context |
| **DIVERS** | Miscellaneous / sandbox |

---

## 📈 Statistics

### Notes per Customer

```dataview
TABLE WITHOUT ID
  cust_code as "Customer",
  length(rows) as "Total Notes"
FROM "Run"
WHERE cust_code
GROUP BY cust_code
SORT cust_code ASC
```

### Notes per Section

```dataview
TABLE WITHOUT ID
  section as "Section",
  length(rows) as "Count"
FROM "Run"
WHERE section
GROUP BY section
```

---

## ⚡ Quick Actions

- Create a new note in any CUST section folder → Templater auto-applies the correct template
- Use `Ctrl+Shift+T` to manually insert a template

---

## 🔧 Maintenance

- Last structure update: `{now_local}`
- Configuration: [[_config/cust-run-config|View Config]] *(if you create this note)*
'''

print(hub)
PYTHON
)

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY-RUN] Would write enhanced Run-Hub.md"
        echo "$hub_content" | head -50
        echo "..."
    else
        echo "$hub_content" > "$hub_file"
        log_success "Enhanced Run-Hub.md written: $hub_file"
    fi
}

#######################################
# Main
#######################################
show_usage() {
    cat <<EOF
Usage: $(basename "$0") COMMAND

Commands:
  check     Check if required plugins are installed
  plugins   Configure Obsidian plugin settings
  hub       Generate enhanced Run-Hub.md with Dataview queries
  init      Full vault initialization (structure + templates + plugins + hub)

Environment:
  DRY_RUN=true    Show what would be done without making changes
EOF
}

case "${1:-}" in
    check)
        cmd_check
        ;;
    plugins)
        cmd_plugins
        ;;
    hub)
        cmd_hub
        ;;
    init)
        cmd_init
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
