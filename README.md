# AutoVault

Helper scripts to create, template, verify, and clean a "Run" workspace in an Obsidian vault. Each customer gets a `CUST-XXX` folder with section subfolders, index files, and a global `Run-Hub.md` linking to every customer.

## Features

- **Structure generation** – Creates customer folders (`CUST-001`, `CUST-002`, …) with configurable section subfolders and a central `Run-Hub.md`
- **Template application** – Applies Markdown templates with placeholder substitution (`{{CUST_CODE}}`, `{{SECTION}}`, `{{NOW_UTC}}`, `{{NOW_LOCAL}}`)
- **Verification** – Validates folder structure, index files, and hub links
- **Cleanup** – Removes customer folders (protected by safety flags)
- **Cross-platform** – Independent implementations in Bash (Linux/macOS) and PowerShell (Windows)

## Generated Structure

```
<VaultRoot>/
├── Run/
│   ├── CUST-002/
│   │   ├── CUST-002-Index.md
│   │   ├── CUST-002-FP/
│   │   │   └── CUST-002-FP-Index.md
│   │   ├── CUST-002-RAISED/
│   │   │   └── CUST-002-RAISED-Index.md
│   │   ├── CUST-002-INFORMATIONS/
│   │   │   └── CUST-002-INFORMATIONS-Index.md
│   │   └── CUST-002-DIVERS/
│   │       └── CUST-002-DIVERS-Index.md
│   └── ...
└── Run-Hub.md
```

## Requirements

### Linux / macOS
- Bash 4+
- `jq` (for JSON parsing)
- `python3` (for JSON generation)

### Windows
- PowerShell 5.1+ or PowerShell 7+

## Configure

### Interactive Mode

The easiest way to configure the project is using the interactive wizard:

```bash
# Linux / macOS
./cust-run-config.sh config

# Windows (PowerShell)
.\cust-run-config.ps1 config
```

The wizard first displays the current configuration, then prompts for each value:

```
[INFO ] Interactive configuration mode
[INFO ] Press Enter to keep current/default values

Current configuration:
  1. VaultRoot:            D:\Obsidian\Work-Vault
  2. CustomerIdWidth:      3
  3. CustomerIds:          2 4 5 7 10 11 12 14 15 18 25 27 29 30
  4. Sections:             FP RAISED INFORMATIONS DIVERS
  5. TemplateRelativeRoot: _templates\Run

Vault root path [D:\Obsidian\Work-Vault]: 
Customer ID width (padding) [3]: 
...
```

Configuration parameters:
- **Vault root path** – path to your Obsidian vault
- **Customer ID width** – zero-padding width (default 3, e.g., `CUST-002`)
- **Customer IDs** – space-separated list of numeric customer codes
- **Sections** – space-separated section names
- **Template relative root** – relative path to templates folder

### Manual Configuration

Edit the configuration values in `cust-run-config.sh` (Linux) or `cust-run-config.ps1` (Windows):

- `VAULT_ROOT` – path to your vault
- `CUSTOMER_ID_WIDTH` – zero-padding width (default 3)
- `CUSTOMER_IDS` – list of numeric customer codes
- `SECTIONS` – section names (defaults to `FP RAISED INFORMATIONS DIVERS`)
- `TEMPLATE_RELATIVE_ROOT` – relative path to templates (defaults to `_templates/Run`)

Running the orchestrator will generate `config/cust-run-config.json` which is shared between both platforms.

## Usage

### Linux / macOS (Bash)

```bash
./cust-run-config.sh config      # Interactive configuration wizard
./cust-run-config.sh structure   # Create/refresh folder structure
./cust-run-config.sh templates   # Apply markdown templates
./cust-run-config.sh test        # Verify structure & indexes
./cust-run-config.sh cleanup     # Remove CUST folders (protected)
```

### Windows (PowerShell)

```powershell
.\cust-run-config.ps1 config      # Interactive configuration wizard
.\cust-run-config.ps1 structure   # Create/refresh folder structure
.\cust-run-config.ps1 templates   # Apply markdown templates
.\cust-run-config.ps1 test        # Verify structure & indexes
.\cust-run-config.ps1 cleanup     # Remove CUST folders (protected)
```

## Shared Configuration

Both platforms read and write the same `config/cust-run-config.json` file:

```json
{
  "VaultRoot": "D:\\Obsidian\\Work-Vault",
  "CustomerIdWidth": 3,
  "CustomerIds": [2, 4, 5, 7, 10],
  "Sections": ["FP", "RAISED", "INFORMATIONS", "DIVERS"],
  "TemplateRelativeRoot": "_templates\\Run"
}
```

Edit this file directly or modify the values in the orchestrator scripts and re-run them.

## Safety Notes

### Cleanup protection

Cleanup is **disabled by default** to prevent accidental data loss. To enable deletions:

- **PowerShell**: Set `$EnableDeletion = $true` in `powershell/Cleanup-CustRunStructure.ps1`
- **Bash**: Set `ENABLE_DELETION=true` in `bash/Cleanup-CustRunStructure.sh`

To also remove `Run-Hub.md`:

- **PowerShell**: Set `$RemoveHub = $true`
- **Bash**: Set `REMOVE_HUB=true`

## Generate Templates from JSON

Use `Generate-CustRunTemplates.sh` (Linux) or `Generate-CustRunTemplates.ps1` (Windows) to populate the `_templates/Run` folder from a JSON description:

```bash
# Linux
./Generate-CustRunTemplates.sh cust-run-templates.json

# Windows
.\Generate-CustRunTemplates.ps1 cust-run-templates.json
```

Copy `cust-run-templates.sample.json` to `cust-run-templates.json` and customize:

```json
{
  "Templates": [
    {"FileName": "CUST-Root-Index.md", "Content": "# {{CUST_CODE}} ..."},
    {"FileName": "CUST-Section-FP-Index.md", "Content": "# {{CUST_CODE}} | {{SECTION}} ..."}
  ]
}
```

Placeholders (`{{CUST_CODE}}`, `{{SECTION}}`, `{{NOW_UTC}}`, `{{NOW_LOCAL}}`) are replaced when `Apply-CustRunTemplates` runs.

## Project Structure

```
AutoVault/
├── cust-run-config.sh              # Linux orchestrator
├── cust-run-config.ps1             # Windows orchestrator
├── Generate-CustRunTemplates.sh    # Template generator (Linux)
├── Generate-CustRunTemplates.ps1   # Template generator (Windows)
├── cust-run-templates.sample.json  # Template definitions sample
├── README.md
├── config/
│   └── cust-run-config.json        # Shared configuration (auto-generated)
├── bash/                           # Linux scripts
│   ├── Apply-CustRunTemplates.sh
│   ├── Cleanup-CustRunStructure.sh
│   ├── New-CustRunStructure.sh
│   └── Test-CustRunStructure.sh
└── powershell/                     # Windows scripts
    ├── Apply-CustRunTemplates.ps1
    ├── Cleanup-CustRunStructure.ps1
    ├── New-CustRunStructure.ps1
    └── Test-CustRunStructure.ps1
```
