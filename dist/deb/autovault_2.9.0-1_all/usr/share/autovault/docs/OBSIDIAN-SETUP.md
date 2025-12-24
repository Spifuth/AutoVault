# 🔌 Obsidian Setup Guide

How to set up Obsidian for AutoVault.

---

## Required Plugins

Install these from Obsidian Community Plugins:

| Plugin | Purpose |
|--------|---------|
| **Templater** | Auto-apply templates when creating notes |
| **Dataview** | Dynamic queries in Run-Hub dashboard |

### Installation

1. Open Obsidian
2. Go to `Settings → Community plugins`
3. Click `Browse`
4. Search and install:
   - "Templater" by SilentVoid13
   - "Dataview" by Michael Brenan
5. Enable both plugins

---

## Automatic Configuration

AutoVault can configure plugins automatically:

```bash
./cust-run-config.sh vault plugins
```

This configures:
- Templater folder templates
- Dataview JS queries
- Bookmarks
- Hotkeys

**Restart Obsidian after running this command.**

---

## Manual Configuration

### Templater Settings

`Settings → Templater`:

| Setting | Value |
|---------|-------|
| Template folder location | `_templates` |
| Trigger Templater on new file creation | ✅ Enabled |
| Enable folder templates | ✅ Enabled |

#### Folder Templates

Add these folder templates:

| Folder | Template |
|--------|----------|
| `Run/CUST-*/CUST-*-FP` | `_templates/Run/RUN - New FP note.md` |
| `Run/CUST-*/CUST-*-RAISED` | `_templates/Run/RUN - New RAISED note.md` |
| `Run/CUST-*/CUST-*-INFORMATIONS` | `_templates/Run/RUN - New INFORMATIONS note.md` |
| `Run/CUST-*/CUST-*-DIVERS` | `_templates/Run/RUN - New DIVERS note.md` |

### Dataview Settings

`Settings → Dataview`:

| Setting | Value |
|---------|-------|
| Enable JavaScript Queries | ✅ Enabled |
| Enable Inline JavaScript Queries | ✅ Enabled |
| Enable Inline Field Highlighting | ✅ Enabled |

---

## Verify Setup

Check if plugins are properly installed:

```bash
./cust-run-config.sh vault check
```

Expected output:
```
[INFO ] Checking Obsidian plugins installation...
[INFO ] ✓ Templater plugin found
[INFO ] ✓ Dataview plugin found
[OK   ] All required plugins are installed
```

---

## Using Templates

### Creating a New Note

1. Navigate to a CUST section folder (e.g., `CUST-002-FP/`)
2. Create a new note (`Ctrl+N` or right-click → New note)
3. Templater automatically applies the template
4. Fill in the prompts (alert name, ticket ID, etc.)
5. The file is renamed automatically

### Manual Template Insertion

Press `Ctrl+Shift+T` to manually insert a template.

---

## Run-Hub Dashboard

The Run-Hub uses Dataview queries to show:

### Open Incidents

```dataview
TABLE WITHOUT ID
  file.link as "Incident",
  cust_code as "Customer",
  severity as "Severity",
  status as "Status"
FROM "Run"
WHERE type = "cust-run-raised-note" AND status != "Closed"
SORT severity DESC
```

### Recent Activity

```dataview
TABLE WITHOUT ID
  file.link as "Note",
  file.folder as "Location",
  file.mtime as "Modified"
FROM "Run"
SORT file.mtime DESC
LIMIT 10
```

Regenerate the hub:

```bash
./cust-run-config.sh vault hub
```

---

## Troubleshooting

### Templates not auto-applying

1. Check Templater is enabled
2. Verify folder templates are configured
3. Restart Obsidian
4. Run `./cust-run-config.sh vault plugins` again

### Dataview queries not rendering

1. Check Dataview is enabled
2. Enable JavaScript queries in settings
3. Restart Obsidian

### File paths not working

WSL users: Use `/mnt/c/...` paths instead of `C:\...`

```bash
./cust-run-config.sh config
# Enter: /mnt/c/Users/username/Documents/Obsidian/MyVault
```

---

## Files Modified by AutoVault

AutoVault writes to these Obsidian config files:

```
.obsidian/
├── plugins/
│   ├── templater-obsidian/
│   │   └── data.json          # Templater settings
│   └── dataview/
│       └── data.json          # Dataview settings
├── bookmarks.json             # Bookmarked files
├── hotkeys.json               # Custom hotkeys
├── app.json                   # App settings
└── community-plugins.json     # Enabled plugins list
```

These are merged with existing settings (not overwritten completely).
