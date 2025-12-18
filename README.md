# AutoVault

> **Version 1.3** – Code quality audit, ShellCheck compliance, and reliability improvements.

Helper scripts to create, template, verify, and clean a "Run" workspace in an Obsidian vault. Each customer gets a `CUST-XXX` folder with section subfolders, index files, and a global `Run-Hub.md` linking to every customer.

## Features

- **Structure generation** – Creates customer folders (`CUST-001`, `CUST-002`, …) with configurable section subfolders and a central `Run-Hub.md`
- **Template application** – Applies Markdown templates with placeholder substitution (`{{CUST_CODE}}`, `{{SECTION}}`, `{{NOW_UTC}}`, `{{NOW_LOCAL}}`)
- **Verification** – Validates folder structure, index files, and hub links
- **Cleanup** – Removes customer folders (protected by safety flags)
- **Customer & Section Management** – Add/remove customers and sections dynamically
- **Backup Management** – List, create, and restore configuration backups
- **Configuration Validation** – Validate JSON config with automatic fixes
- **Modular Architecture** – Shared libraries for logging and config management
- **Cross-platform** – Works on Linux, macOS, and Windows (via WSL) with automatic path conversion

## Generated Structure

\`\`\`
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
\`\`\`

## Requirements

### Linux / macOS
- Bash 4+
- \`jq\` (for JSON parsing)
- \`python3\` (for JSON generation)

### Windows
- **WSL (Windows Subsystem for Linux)** – Required to run the Bash scripts
- Inside WSL: Bash 4+, \`jq\`, \`python3\`

To install WSL on Windows 10/11:
\`\`\`powershell
wsl --install
\`\`\`

Then install dependencies inside WSL:
\`\`\`bash
sudo apt update && sudo apt install -y jq python3
\`\`\`

Your Windows vault path will be accessible from WSL at \`/mnt/c/...\` (e.g., \`/mnt/c/Users/YourName/Obsidian/Work-Vault\`).

### Auto-Install Requirements

The script can automatically check and install missing requirements:

\`\`\`bash
./cust-run-config.sh requirements check    # Check what's installed
./cust-run-config.sh requirements install  # Install missing deps
\`\`\`

Detects and uses the available package manager (apt, dnf, yum, pacman, zypper, brew, apk) to install \`jq\` and \`python3\`.

## Configure

### Interactive Mode

The easiest way to configure the project is using the interactive wizard:

\`\`\`bash
./cust-run-config.sh config
\`\`\`

The wizard first displays the current configuration, then prompts for each value:

\`\`\`
[INFO ] Interactive configuration mode
[INFO ] Press Enter to keep current/default values

Current configuration:
  1. VaultRoot:            /mnt/c/Users/YourName/Obsidian/Work-Vault
  2. CustomerIdWidth:      3
  3. CustomerIds:          2 4 5 7 10 11 12 14 15 18 25 27 29 30
  4. Sections:             FP RAISED INFORMATIONS DIVERS
  5. TemplateRelativeRoot: _templates/Run

Vault root path [/mnt/c/Users/YourName/Obsidian/Work-Vault]: 
Customer ID width (padding) [3]: 
...
\`\`\`

Configuration parameters:
- **Vault root path** – path to your Obsidian vault (use \`/mnt/c/...\` for Windows paths in WSL)
- **Customer ID width** – zero-padding width (default 3, e.g., \`CUST-002\`)
- **Customer IDs** – space-separated list of numeric customer codes
- **Sections** – space-separated section names
- **Template relative root** – relative path to templates folder

### Manual Configuration

Edit \`config/cust-run-config.json\` directly:

\`\`\`json
{
  "VaultRoot": "/mnt/c/Users/YourName/Obsidian/Work-Vault",
  "CustomerIdWidth": 3,
  "CustomerIds": [2, 4, 5, 7, 10],
  "Sections": ["FP", "RAISED", "INFORMATIONS", "DIVERS"],
  "TemplateRelativeRoot": "_templates/Run"
}
\`\`\`

## Usage

\`\`\`bash
# Global options (can be combined with any command)
./cust-run-config.sh -v <command>       # Verbose/debug output
./cust-run-config.sh -q <command>       # Quiet mode (errors only)
./cust-run-config.sh --silent <command> # Silent mode (no output)
./cust-run-config.sh --no-color <command> # Disable colored output
./cust-run-config.sh --dry-run <command>  # Preview without changes
./cust-run-config.sh -h                 # Show help

# Configuration
./cust-run-config.sh config             # Interactive configuration wizard
./cust-run-config.sh validate           # Validate configuration file
./cust-run-config.sh status             # Show comprehensive status report

# Structure Management
./cust-run-config.sh structure          # Create/refresh folder structure
./cust-run-config.sh templates          # Apply markdown templates
./cust-run-config.sh test               # Verify structure & indexes
./cust-run-config.sh cleanup            # Remove CUST folders (protected)

# Customer Management
./cust-run-config.sh customer add 31    # Add customer ID 31
./cust-run-config.sh customer remove 5  # Remove customer ID 5
./cust-run-config.sh customer list      # List all customers

# Section Management
./cust-run-config.sh section add URGENT     # Add new section
./cust-run-config.sh section remove DIVERS  # Remove section
./cust-run-config.sh section list           # List all sections

# Backup Management
./cust-run-config.sh backup list        # List available backups
./cust-run-config.sh backup restore 1   # Restore backup #1
./cust-run-config.sh backup create      # Create manual backup
./cust-run-config.sh backup cleanup 10  # Keep only 10 most recent

# Requirements
./cust-run-config.sh requirements check   # Check dependencies
./cust-run-config.sh requirements install # Install missing deps
\`\`\`

## Safety Notes

### Hub file preservation

When running \`structure\`, if \`Run-Hub.md\` already exists, it will **not be overwritten**. This preserves any manual edits you've made. To regenerate the hub file, delete it first and re-run the structure command.

### Cleanup protection

Cleanup is **disabled by default** to prevent accidental data loss. To enable deletions, set \`ENABLE_DELETION=true\` in \`bash/Cleanup-CustRunStructure.sh\`.

To also remove \`Run-Hub.md\`, set \`REMOVE_HUB=true\`.

## Generate Templates from JSON

Use \`Generate-CustRunTemplates.sh\` to populate the \`_templates/Run\` folder from a JSON description:

\`\`\`bash
./Generate-CustRunTemplates.sh cust-run-templates.json
\`\`\`

Copy \`cust-run-templates.sample.json\` to \`cust-run-templates.json\` and customize:

\`\`\`json
{
  "Templates": [
    {"FileName": "CUST-Root-Index.md", "Content": "# {{CUST_CODE}} ..."},
    {"FileName": "CUST-Section-FP-Index.md", "Content": "# {{CUST_CODE}} | {{SECTION}} ..."}
  ]
}
\`\`\`

Placeholders (\`{{CUST_CODE}}\`, \`{{SECTION}}\`, \`{{NOW_UTC}}\`, \`{{NOW_LOCAL}}\`) are replaced when running \`templates\`.

## Project Structure

\`\`\`
AutoVault/
├── cust-run-config.sh              # Main CLI orchestrator (entry point)
├── Generate-CustRunTemplates.sh    # Template generator
├── cust-run-templates.sample.json  # Template definitions sample
├── README.md
├── config/
│   └── cust-run-config.json        # Configuration (auto-generated)
├── backups/                        # Configuration backups (auto-created)
└── bash/
    ├── lib/                        # Shared libraries
    │   ├── logging.sh              # Logging utilities (colors, log levels)
    │   └── config.sh               # Config loading/saving functions
    ├── Manage-Customers.sh         # Customer add/remove/list
    ├── Manage-Sections.sh          # Section add/remove/list
    ├── Manage-Backups.sh           # Backup list/restore/create/cleanup
    ├── Show-Status.sh              # Status report display
    ├── Validate-Config.sh          # Configuration validation
    ├── Install-Requirements.sh     # Dependency management
    ├── New-CustRunStructure.sh     # Create folder structure
    ├── Apply-CustRunTemplates.sh   # Apply markdown templates
    ├── Test-CustRunStructure.sh    # Verify structure
    └── Cleanup-CustRunStructure.sh # Remove structure (protected)
\`\`\`

## Architecture

The project uses a modular architecture:

- **\`cust-run-config.sh\`** - Main CLI orchestrator (~350 lines). Parses arguments and dispatches to feature scripts.
- **\`bash/lib/logging.sh\`** - Shared logging with LOG_LEVEL support (0=silent, 1=error, 2=warn, 3=info, 4=debug) and NO_COLOR support.
- **`bash/lib/config.sh`** - Configuration management: load/save JSON config, default values, helper functions. Includes trap-based cleanup for temp files.
- **Feature scripts** - Each command has its own script that sources the shared libraries.

## Code Quality

The codebase follows bash best practices:

- **ShellCheck compliant** – All scripts pass [ShellCheck](https://www.shellcheck.net/) static analysis
- **Consistent logging** – Unified `log_info`, `log_warn`, `log_error`, `log_debug`, `log_success` functions
- **Safe defaults** – Destructive operations require explicit opt-in (`ENABLE_DELETION=true`)
- **Portable paths** – Automatic tilde expansion (`~`) and Windows path conversion (`\` → `/`)
- **Proper cleanup** – Trap handlers ensure temp files are removed on interruption

## Changelog

### v1.3 (December 2024)
- ✅ Full ShellCheck compliance (SC2034, SC2059, SC2207 fixes)
- ✅ Added trap cleanup for temp files in config operations
- ✅ Standardized logging functions across all scripts
- ✅ Fixed boolean comparison quoting
- ✅ Unified confirmation prompts to `[y/N]` pattern
- ✅ Added Windows path and tilde expansion support
- ✅ Removed unused variables and legacy code

### v1.1
- Initial modular architecture
- Customer and section management
- Backup system
- Configuration validation

## License

MIT
