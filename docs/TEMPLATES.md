# 📝 Templates Guide

AutoVault uses a template system to populate index files with consistent content.

---

## Template Storage

Templates are stored in two places:

| Location | Purpose |
|----------|---------|
| `config/templates.json` | Source of truth (versioned in Git) |
| `vault/_templates/Run/` | Working copies in Obsidian vault |

---

## Template Types

### Index Templates

Applied to CUST folder index files by the `templates apply` command.

| Template | Target |
|----------|--------|
| `root` | `CUST-XXX/CUST-XXX-Index.md` |
| `sections.FP` | `CUST-XXX/CUST-XXX-FP/CUST-XXX-FP-Index.md` |
| `sections.RAISED` | `CUST-XXX/CUST-XXX-RAISED/CUST-XXX-RAISED-Index.md` |
| `sections.INFORMATIONS` | `CUST-XXX/CUST-XXX-INFORMATIONS/...` |
| `sections.DIVERS` | `CUST-XXX/CUST-XXX-DIVERS/...` |

### Note Templates

Used by Templater when creating new notes in section folders.

| Template | Trigger |
|----------|---------|
| `notes.FP` | Create note in `CUST-XXX-FP/` folder |
| `notes.RAISED` | Create note in `CUST-XXX-RAISED/` folder |
| `notes.INFORMATIONS` | Create note in `CUST-XXX-INFORMATIONS/` folder |
| `notes.DIVERS` | Create note in `CUST-XXX-DIVERS/` folder |

---

## Placeholders

Index templates support these placeholders:

| Placeholder | Replaced With | Example |
|-------------|---------------|---------|
| `{{CUST_CODE}}` | Customer code | `CUST-002` |
| `{{NOW_UTC}}` | Current UTC timestamp | `2025-12-19T14:30:00Z` |
| `{{NOW_LOCAL}}` | Current local timestamp | `2025-12-19T15:30:00+0100` |

---

## Template Commands

### Apply Templates

Apply templates to all CUST folders (replaces placeholders):

```bash
./cust-run-config.sh templates apply
./cust-run-config.sh --dry-run templates apply  # Preview
```

### Sync Templates

Write templates from JSON to vault `_templates/` folder:

```bash
./cust-run-config.sh templates sync
```

This creates/updates:
- `_templates/Run/CUST-Root-Index.md`
- `_templates/Run/CUST-Section-FP-Index.md`
- `_templates/Run/CUST-Section-RAISED-Index.md`
- `_templates/Run/CUST-Section-INFORMATIONS-Index.md`
- `_templates/Run/CUST-Section-DIVERS-Index.md`
- `_templates/Run/RUN - New FP note.md`
- `_templates/Run/RUN - New RAISED note.md`
- `_templates/Run/RUN - New INFORMATIONS note.md`
- `_templates/Run/RUN - New DIVERS note.md`

### Export Templates

Read templates from vault and update JSON:

```bash
./cust-run-config.sh templates export
```

Use this after manually editing templates in Obsidian to save changes back to JSON.

---

## Customizing Templates

### Method 1: Edit JSON directly

Edit `config/templates.json`, then sync:

```bash
# Edit config/templates.json
./cust-run-config.sh templates sync   # Update vault
./cust-run-config.sh templates apply  # Apply to CUST folders
```

### Method 2: Edit in Obsidian

Edit templates in `_templates/Run/`, then export:

```bash
# Edit in Obsidian
./cust-run-config.sh templates export  # Save to JSON
```

---

## Note Templates (Templater)

Note templates use [Templater](https://github.com/SilentVoid13/Templater) syntax.

### How It Works

When you create a new note in a CUST section folder:
1. Templater detects the folder
2. Applies the corresponding template
3. Prompts for required information
4. Renames the file automatically

### Example: FP Note Template

```javascript
<%*
const fullPath = tp.file.path(true);
const parts = fullPath.split("/");
const custPart = parts.find(p => p.startsWith("CUST-"));
const custCode = custPart ?? await tp.system.prompt("CUST code (ex: CUST-002)");

const alertName = await tp.system.prompt("Alert name for this FP?");
const nowUtc = moment().utc().format();

await tp.file.rename(`${custCode}-FP - ${alertName}`);

tR = `---
title: "${custCode} - FP - ${alertName}"
cust_code: "${custCode}"
section: "FP"
created_utc: "${nowUtc}"
type: "cust-run-fp-note"
---

# ${custCode} – FP pattern – ${alertName}
...
`;
%>
```

---

## Folder Templates Configuration

AutoVault configures Templater to auto-apply templates based on folder:

| Folder Pattern | Template Applied |
|----------------|------------------|
| `Run/CUST-*/CUST-*-FP` | `RUN - New FP note.md` |
| `Run/CUST-*/CUST-*-RAISED` | `RUN - New RAISED note.md` |
| `Run/CUST-*/CUST-*-INFORMATIONS` | `RUN - New INFORMATIONS note.md` |
| `Run/CUST-*/CUST-*-DIVERS` | `RUN - New DIVERS note.md` |

This is configured automatically by:

```bash
./cust-run-config.sh vault plugins
```

---

## Adding a New Section Template

1. Add section to config:
   ```bash
   ./cust-run-config.sh section add URGENT
   ```

2. Edit `config/templates.json`:
   ```json
   {
     "templates": {
       "index": {
         "sections": {
           "URGENT": "---\ntitle: \"{{CUST_CODE}} - URGENT\"\n..."
         }
       },
       "notes": {
         "URGENT": "<%* ... Templater code ... %>"
       }
     }
   }
   ```

3. Sync and apply:
   ```bash
   ./cust-run-config.sh templates sync
   ./cust-run-config.sh templates apply
   ```

4. Update Obsidian plugin config:
   ```bash
   ./cust-run-config.sh vault plugins
   ```
