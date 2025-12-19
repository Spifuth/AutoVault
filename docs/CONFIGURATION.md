# ⚙️ Configuration Guide

AutoVault uses JSON configuration files to manage settings.

---

## Configuration Files

| File | Description |
|------|-------------|
| `config/cust-run-config.json` | Main configuration (vault path, customers, sections) |
| `config/templates.json` | All templates stored as JSON |
| `config/obsidian-settings.json` | Obsidian plugin settings |

---

## Main Configuration

### File: `config/cust-run-config.json`

```json
{
  "VaultRoot": "/path/to/your/vault",
  "CustomerIdWidth": 3,
  "CustomerIds": [2, 4, 5, 7, 10, 11],
  "Sections": ["FP", "RAISED", "INFORMATIONS", "DIVERS"],
  "TemplateRelativeRoot": "_templates/Run",
  "EnableCleanup": false
}
```

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `VaultRoot` | string | Absolute path to your Obsidian vault |
| `CustomerIdWidth` | number | Zero-padding width for customer IDs (3 → CUST-007) |
| `CustomerIds` | number[] | List of customer IDs to manage |
| `Sections` | string[] | Section names (folders under each customer) |
| `TemplateRelativeRoot` | string | Path to templates folder relative to vault |
| `EnableCleanup` | boolean | Safety flag for cleanup command |

---

## Interactive Configuration

The easiest way to configure:

```bash
./cust-run-config.sh config
```

This prompts for each value and saves to `config/cust-run-config.json`.

---

## Path Formats

### Linux/macOS
```json
"VaultRoot": "/home/user/Documents/MyVault"
```

### WSL (accessing Windows drive)
```json
"VaultRoot": "/mnt/c/Users/username/Documents/Obsidian/MyVault"
```

### Windows paths (auto-converted)
```json
"VaultRoot": "C:\\Users\\username\\Documents\\Obsidian\\MyVault"
```

AutoVault automatically converts Windows-style backslashes to forward slashes.

---

## Customer IDs

Customer IDs are integers that get zero-padded based on `CustomerIdWidth`:

| ID | Width | Result |
|----|-------|--------|
| 2 | 3 | CUST-002 |
| 42 | 3 | CUST-042 |
| 123 | 3 | CUST-123 |
| 5 | 4 | CUST-0005 |

---

## Sections

Default sections for SOC/RUN workflows:

| Section | Purpose |
|---------|---------|
| `FP` | First Pass - routine checks, triage patterns |
| `RAISED` | Incidents and tickets raised |
| `INFORMATIONS` | Knowledge base, contacts, environment info |
| `DIVERS` | Miscellaneous, sandbox, temporary notes |

You can customize sections:

```bash
./cust-run-config.sh section add URGENT
./cust-run-config.sh section remove DIVERS
```

---

## Validation

Validate your configuration:

```bash
./cust-run-config.sh validate
```

Auto-fix common issues:

```bash
./cust-run-config.sh validate --fix
```

Fixes:
- Remove duplicate customer IDs
- Sort customer IDs
- Remove empty sections

---

## Environment Variables

Override configuration via environment:

```bash
# Override config file location
CONFIG_JSON=/path/to/custom-config.json ./cust-run-config.sh status

# Override templates file
TEMPLATES_JSON=/path/to/templates.json ./cust-run-config.sh templates apply

# Enable dry-run
DRY_RUN=true ./cust-run-config.sh structure
```

---

## Backup Configuration

Backups are stored in `backups/` directory:

```
backups/
├── cust-run-config.2025-12-19_143022.json
├── cust-run-config.2025-12-19_150000.json
└── ...
```

Manage backups:

```bash
./cust-run-config.sh backup list
./cust-run-config.sh backup create "Before migration"
./cust-run-config.sh backup restore
./cust-run-config.sh backup cleanup 5  # Keep last 5
```
