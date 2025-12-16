# AutoVault

Helper scripts to create, template, verify, and clean a "Run" workspace in an Obsidian vault. Each customer gets a `CUST-XXX` folder with section subfolders, index files, and a global `Run-Hub.md` linking to every customer.

## Features

- **Structure generation** – Creates customer folders (`CUST-001`, `CUST-002`, …) with configurable section subfolders and a central `Run-Hub.md`
- **Template application** – Applies Markdown templates with placeholder substitution (`{{CUST_CODE}}`, `{{SECTION}}`, `{{NOW_UTC}}`, `{{NOW_LOCAL}}`)
- **Verification** – Validates folder structure, index files, and hub links
- **Cleanup** – Removes customer folders (protected by safety flags)
- **Customer & Section Management** – Add/remove customers and sections dynamically
- **Backup Management** – List, create, and restore configuration backups
- **Configuration Validation** – Validate JSON config with automatic fixes
- **Cross-platform** – Independent implementations in Bash (Linux/macOS) and PowerShell (Windows)
- **Modular Architecture** – Shared libraries for logging and config management

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
- Git (optional)

### Auto-Install Requirements

Both orchestrators can automatically check and install missing requirements:

```bash
# Linux / macOS
./cust-run-config.sh install

# Windows (PowerShell)
.\cust-run-config.ps1 install
```

**Linux/macOS**: Detects and uses the available package manager (apt, dnf, yum, pacman, zypper, brew, apk) to install `jq` and `python3`.

**Windows**: Detects and uses the available package manager (winget, chocolatey, scoop) to install optional tools like Git.

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
# Global options (can be combined with any command)
./cust-run-config.sh -v <command>      # Verbose/debug output
./cust-run-config.sh -q <command>      # Quiet mode (errors only)
./cust-run-config.sh --silent <command> # Silent mode (no output)
./cust-run-config.sh --no-color <command> # Disable colored output
./cust-run-config.sh --dry-run <command>  # Preview without changes
./cust-run-config.sh -h                # Show help

# Configuration
./cust-run-config.sh config            # Interactive configuration wizard
./cust-run-config.sh validate          # Validate configuration file
./cust-run-config.sh status            # Show comprehensive status report

# Structure Management
./cust-run-config.sh structure         # Create/refresh folder structure
./cust-run-config.sh templates         # Apply markdown templates
./cust-run-config.sh test              # Verify structure & indexes
./cust-run-config.sh cleanup           # Remove CUST folders (protected)

# Customer Management
./cust-run-config.sh customer add 31   # Add customer ID 31
./cust-run-config.sh customer remove 5 # Remove customer ID 5
./cust-run-config.sh customer list     # List all customers

# Section Management
./cust-run-config.sh section add URGENT    # Add new section
./cust-run-config.sh section remove DIVERS # Remove section
./cust-run-config.sh section list          # List all sections

# Backup Management
./cust-run-config.sh backup list       # List available backups
./cust-run-config.sh backup restore 1  # Restore backup #1
./cust-run-config.sh backup create     # Create manual backup
./cust-run-config.sh backup cleanup 10 # Keep only 10 most recent

# Requirements
./cust-run-config.sh requirements check   # Check dependencies
./cust-run-config.sh requirements install # Install missing deps
```

### Windows (PowerShell)

```powershell
.\cust-run-config.ps1 install     # Check/install requirements
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

### Hub file preservation

When running `structure`, if `Run-Hub.md` already exists, it will **not be overwritten**. This preserves any manual edits you've made. To regenerate the hub file, delete it first and re-run the structure command.

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
├── cust-run-config.sh              # Linux CLI orchestrator (main entry point)
├── cust-run-config.ps1             # Windows orchestrator
├── install-requirements.sh         # Standalone requirements installer
├── Generate-CustRunTemplates.sh    # Template generator (Linux)
├── Generate-CustRunTemplates.ps1   # Template generator (Windows)
├── cust-run-templates.sample.json  # Template definitions sample
├── README.md
├── config/
│   └── cust-run-config.json        # Shared configuration (auto-generated)
├── backups/                        # Configuration backups (auto-created)
├── bash/
│   ├── lib/                        # Shared libraries
│   │   ├── logging.sh              # Logging utilities (colors, log levels)
│   │   └── config.sh               # Config loading/saving functions
│   ├── Manage-Customers.sh         # Customer add/remove/list
│   ├── Manage-Sections.sh          # Section add/remove/list
│   ├── Manage-Backups.sh           # Backup list/restore/create/cleanup
│   ├── Show-Status.sh              # Status report display
│   ├── Validate-Config.sh          # Configuration validation
│   ├── Install-Requirements.sh     # Dependency management
│   ├── New-CustRunStructure.sh     # Create folder structure
│   ├── Apply-CustRunTemplates.sh   # Apply markdown templates
│   ├── Test-CustRunStructure.sh    # Verify structure
│   └── Cleanup-CustRunStructure.sh # Remove structure (protected)
└── powershell/                     # Windows scripts
    ├── Apply-CustRunTemplates.ps1
    ├── Cleanup-CustRunStructure.ps1
    ├── New-CustRunStructure.ps1
    └── Test-CustRunStructure.ps1
```

## Architecture

The Bash implementation uses a modular architecture:

- **`cust-run-config.sh`** - Main CLI orchestrator (~350 lines). Parses arguments and dispatches to feature scripts.
- **`bash/lib/logging.sh`** - Shared logging with LOG_LEVEL support (0=silent, 1=error, 2=warn, 3=info, 4=debug) and NO_COLOR support.
- **`bash/lib/config.sh`** - Configuration management: load/save JSON config, default values, helper functions.
- **Feature scripts** - Each command has its own script that sources the shared libraries.
