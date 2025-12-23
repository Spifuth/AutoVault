# 📘 CLI Commands Reference

Complete reference for all AutoVault commands.

---

## Global Options

All commands support these options:

| Option | Description |
|--------|-------------|
| `-v, --verbose` | Enable debug output |
| `-q, --quiet` | Only show errors |
| `--silent` | Suppress all output |
| `--no-color` | Disable colored output |
| `--dry-run` | Preview without making changes |
| `-h, --help` | Show help message |

---

## Configuration Commands

### `config` / `init`

Interactive configuration wizard.

```bash
./cust-run-config.sh config
```

Prompts for:
- Vault root path
- Customer ID width (padding)
- Customer IDs list
- Sections list
- Template relative root
- Enable cleanup flag

### `validate`

Validate the configuration file.

```bash
./cust-run-config.sh validate
./cust-run-config.sh validate --fix  # Auto-fix issues
```

### `status`

Show current status and configuration summary.

```bash
./cust-run-config.sh status
```

Displays:
- Config file status
- Vault directory status
- Customer counts (complete/missing)
- Sections list
- Backup count
- Dependencies status

---

## Vault Management Commands

### `vault init`

**Full vault initialization** - the recommended way to set up a new vault.

```bash
./cust-run-config.sh vault init
```

Performs:
1. Creates folder structure (`structure`)
2. Syncs templates to vault (`templates sync`)
3. Applies templates to CUST folders (`templates apply`)
4. Configures Obsidian plugins (`vault plugins`)

### `vault plugins`

Configure Obsidian plugin settings.

```bash
./cust-run-config.sh vault plugins
```

Configures:
- Templater folder templates
- Dataview settings
- Bookmarks (Run-Hub)
- Hotkeys
- App settings

### `vault check`

Check if required Obsidian plugins are installed.

```bash
./cust-run-config.sh vault check
```

### `vault hub`

Regenerate the Run-Hub.md with Dataview queries.

```bash
./cust-run-config.sh vault hub
```

---

## Structure Management Commands

### `structure` / `new`

Create the folder structure in the vault.

```bash
./cust-run-config.sh structure
./cust-run-config.sh --dry-run structure  # Preview
```

Creates:
- `Run/` directory
- `CUST-XXX/` folders for each customer
- Section subfolders (FP, RAISED, etc.)
- Index files (empty placeholders)
- `Run-Hub.md`

### `templates`

Manage templates (export, sync, apply).

```bash
# Apply templates to CUST folders (default)
./cust-run-config.sh templates apply

# Sync templates from JSON to vault/_templates/
./cust-run-config.sh templates sync

# Export templates from vault to JSON
./cust-run-config.sh templates export
```

### `test` / `verify`

Verify the vault structure is complete.

```bash
./cust-run-config.sh test
```

Checks:
- Vault root exists
- Run folder exists
- Run-Hub.md exists
- All CUST folders exist
- All section folders exist
- All index files exist

### `cleanup`

Remove the vault structure. **Dangerous!**

```bash
./cust-run-config.sh --dry-run cleanup  # Always preview first!
./cust-run-config.sh cleanup
```

Requires `EnableCleanup: true` in config.

---

## Customer Management Commands

### `customer add`

Add a new customer.

```bash
./cust-run-config.sh customer add 31
./cust-run-config.sh customer add 31 --create  # Also create folders
```

### `customer remove`

Remove a customer.

```bash
./cust-run-config.sh customer remove 31
./cust-run-config.sh customer remove 31 --delete  # Also delete folders
```

### `customer list`

List all configured customers.

```bash
./cust-run-config.sh customer list
```

---

## Section Management Commands

### `section add`

Add a new section.

```bash
./cust-run-config.sh section add URGENT
./cust-run-config.sh section add URGENT --create  # Also create folders
```

### `section remove`

Remove a section.

```bash
./cust-run-config.sh section remove URGENT
./cust-run-config.sh section remove URGENT --delete  # Also delete folders
```

### `section list`

List all configured sections.

```bash
./cust-run-config.sh section list
```

---

## Backup Management Commands

### `backup list`

List available backups.

```bash
./cust-run-config.sh backup list
```

### `backup create`

Create a manual backup.

```bash
./cust-run-config.sh backup create "Before major changes"
```

### `backup restore`

Restore a backup.

```bash
./cust-run-config.sh backup restore       # Latest
./cust-run-config.sh backup restore 3     # Specific backup
```

### `backup cleanup`

Clean up old backups.

```bash
./cust-run-config.sh backup cleanup 5     # Keep 5 most recent
```

---

## Requirements Commands

### `requirements check`

Check if dependencies are installed.

```bash
./cust-run-config.sh requirements check
```

### `requirements install`

Install missing dependencies.

```bash
./cust-run-config.sh requirements install
```

---

## Shell Completions Commands

### `completions status`

Show current completion installation status.

```bash
./cust-run-config.sh completions
./cust-run-config.sh completions status
```

Displays:
- Current shell detected
- Installed completions (Bash/Zsh)
- Installation locations
- Source files status

### `completions install`

Install shell completions for tab-completion support.

```bash
# Install for current shell (auto-detected)
./cust-run-config.sh completions install

# Install for specific shell
./cust-run-config.sh completions install bash
./cust-run-config.sh completions install zsh
./cust-run-config.sh completions install all

# Install system-wide (requires sudo)
./cust-run-config.sh completions install --system
```

Installation locations:
- **Bash (user)**: `~/.local/share/bash-completion/completions/`
- **Bash (system)**: `/etc/bash_completion.d/`
- **Zsh (user)**: `~/.zsh/completions/` or `~/.oh-my-zsh/completions/`
- **Zsh (system)**: `/usr/share/zsh/site-functions/`

### `completions uninstall`

Remove installed completion scripts.

```bash
./cust-run-config.sh completions uninstall
./cust-run-config.sh completions uninstall bash
./cust-run-config.sh completions uninstall zsh
```

---

## Alias Commands

### `alias status`

Show current alias installation status.

```bash
./cust-run-config.sh alias
./cust-run-config.sh alias status
```

Displays:
- Script location
- Current shell
- PATH directories status
- Installed aliases (symlinks and shell aliases)

### `alias install`

Create a system alias or symlink for AutoVault.

```bash
# Install with default name (autovault)
./cust-run-config.sh alias install

# Install with custom name
./cust-run-config.sh alias install av
./cust-run-config.sh alias install --name=vault

# Install as shell alias instead of symlink
./cust-run-config.sh alias install --method=alias

# System-wide installation
./cust-run-config.sh alias install --system
```

Methods:
- **symlink** (default): Creates a symbolic link in `~/.local/bin` or `/usr/local/bin`
- **alias**: Adds an alias to your `~/.bashrc` or `~/.zshrc`

Suggested names:
- `autovault` - Full name (default)
- `av` - Short and quick
- `vault` - If you don't use Hashicorp Vault
- `custrun` - Descriptive

### `alias uninstall`

Remove installed alias(es).

```bash
./cust-run-config.sh alias uninstall av
./cust-run-config.sh alias uninstall --all
```

---

## Init Command

### `init`

Initialize a new vault from scratch. The recommended way to start fresh.

```bash
# Quick start with defaults
./cust-run-config.sh init

# Initialize with a specific profile
./cust-run-config.sh init --profile pentest

# Custom vault path
./cust-run-config.sh init --path ~/Documents/SecurityVault

# Reinitialize existing (overwrite config)
./cust-run-config.sh init --force

# Skip creating initial structure
./cust-run-config.sh init --no-structure
```

**Available Profiles:**

| Profile | Description | Sections |
|---------|-------------|----------|
| `minimal` | Basic structure | Notes, Archive |
| `pentest` | Penetration testing | Recon, Enum, Exploit, Post, Findings, Reporting |
| `audit` | Security audit | Scope, Evidence, Findings, Recommendations, Reporting |
| `bugbounty` | Bug bounty hunting | Programs, Targets, Findings, POC, Reporting |

**What it creates:**
- Vault directory
- `config/cust-run-config.json` - Main configuration
- `config/templates.json` - Template definitions
- `_templates/run/root/` - Customer-level templates
- `_templates/run/section/` - Section-level templates
- `_archive/` - For archived customers
- Initial customer folder (unless `--no-structure`)

---

## Doctor Command

### `doctor`

Run comprehensive diagnostics on your AutoVault installation.

```bash
# Run diagnostics
./cust-run-config.sh doctor

# Attempt to fix issues automatically
./cust-run-config.sh doctor --fix

# Verbose output
./cust-run-config.sh doctor --verbose

# JSON output (for scripting)
./cust-run-config.sh doctor --json
```

**Checks performed:**

| Category | Checks |
|----------|--------|
| Dependencies | Bash (>= 4.0), jq (required), Git, rsync, SSH (optional) |
| Configuration | Config file exists/valid, required fields, templates.json, remotes.json |
| Vault Structure | Vault directory, customer folders, templates dir, archive dir |
| Permissions | Main script, bash scripts, hook scripts executable |
| Disk Space | Config disk, vault disk usage and free space |
| Integrations | System alias (av/autovault), shell completions |

**Exit codes:**
- `0` - All checks passed
- `1` - One or more checks failed

---

## Search Command

### `search`

Search across all customers and notes in your vault.

```bash
# Search for text in all notes
./cust-run-config.sh search "password"

# Search in specific customer
./cust-run-config.sh search "SQL injection" --customer ACME
./cust-run-config.sh search "SQLi" -c 001

# Search in specific section
./cust-run-config.sh search "nmap" --section Recon

# Search with regex
./cust-run-config.sh search "CVE-[0-9]{4}-[0-9]+" --regex

# Show only matching filenames
./cust-run-config.sh search report --names-only

# Case-sensitive search
./cust-run-config.sh search "TODO" --case-sensitive

# More context lines
./cust-run-config.sh search "vulnerability" --context 5

# Limit results
./cust-run-config.sh search "error" --max 50

# JSON output
./cust-run-config.sh search "password" --json
```

**Options:**

| Option | Description |
|--------|-------------|
| `-c, --customer <id>` | Search only in specific customer |
| `-s, --section <name>` | Search only in specific section |
| `-t, --type <ext>` | Filter by file type (default: md, use 'all' for all) |
| `-r, --regex` | Treat query as regular expression |
| `-i, --case-sensitive` | Enable case-sensitive search |
| `-n, --names-only` | Show only matching filenames |
| `-C, --context <n>` | Lines of context to show (default: 2) |
| `-m, --max <n>` | Maximum results (default: 100) |
| `--json` | Output as JSON |

---

## Archive Command

### `archive`

Archive a customer's data to a compressed file.

```bash
# Archive customer to default location
./cust-run-config.sh archive ACME

# Archive and remove from vault
./cust-run-config.sh archive ACME --remove

# Custom archive format
./cust-run-config.sh archive ACME --format tar.gz

# Custom output path
./cust-run-config.sh archive ACME --output ~/backups/acme.zip

# Encrypted archive (zip only)
./cust-run-config.sh archive ACME --encrypt

# Force overwrite existing
./cust-run-config.sh archive ACME --force
```

**Supported formats:**

| Format | Extension | Compression |
|--------|-----------|-------------|
| `zip` | .zip | Yes (default) |
| `tar` | .tar | No |
| `tar.gz` | .tar.gz | Yes (gzip) |
| `tar.bz2` | .tar.bz2 | Yes (bzip2) |

**Default output:**
```
vault/_archive/CustRun-<ID>_<YYYYMMDD>.<format>
```

**Restore archived customer:**
```bash
# Restore from zip
unzip -d /path/to/vault archive.zip

# Restore from tar.gz
tar -xzf archive.tar.gz -C /path/to/vault
```

---

## Export Command

### `export`

Export vault content to various formats (PDF, HTML, Markdown) or generate client reports.

**Requirements:**
- `pandoc` - Required for all export formats
- PDF backend (one of): `wkhtmltopdf`, `weasyprint`, or `pdflatex`

```bash
# Export entire vault to PDF
./cust-run-config.sh export pdf vault

# Export customer to HTML
./cust-run-config.sh export html customer ACME

# Export section to Markdown (single file)
./cust-run-config.sh export markdown section RAISED

# Export single file
./cust-run-config.sh export pdf file ./Run/CUST-001/FP/notes.md

# Generate client report
./cust-run-config.sh export report customer ACME --template pentest
```

### Export Subcommands

| Subcommand | Description |
|------------|-------------|
| `pdf` | Export to PDF format |
| `html` | Export to HTML format |
| `markdown` | Export to single merged Markdown file |
| `report` | Generate formatted client report |

### Export Targets

| Target | Description |
|--------|-------------|
| `vault` | Export entire vault |
| `customer <id>` | Export specific customer |
| `section <name>` | Export specific section across all customers |
| `file <path>` | Export single file |

### Export Options

| Option | Description |
|--------|-------------|
| `-o, --output <path>` | Output file path (default: auto-generated) |
| `-t, --template <name>` | Report template: `default`, `pentest`, `audit`, `summary` |
| `--title <text>` | Document title |
| `--author <text>` | Document author |
| `--no-toc` | Disable table of contents |
| `--no-metadata` | Disable metadata header |
| `--page-size <size>` | PDF page size: `A4`, `Letter`, `Legal`, `A3` |
| `--css <file>` | Custom CSS stylesheet |

### Report Templates

| Template | Description | Use Case |
|----------|-------------|----------|
| `default` | Standard format | General documentation |
| `pentest` | Pentest report format | Security assessments |
| `audit` | Audit report format | Compliance audits |
| `summary` | Executive summary | Management reports |

### Examples

```bash
# PDF with custom title and author
./cust-run-config.sh export pdf customer ACME \
    --title "Security Assessment" \
    --author "Security Team"

# HTML with custom CSS
./cust-run-config.sh export html vault \
    --css ~/custom-style.css \
    --output ~/reports/vault-export.html

# Pentest report for client delivery
./cust-run-config.sh export report customer ACME \
    --template pentest \
    --output ~/deliverables/ACME-pentest-report.pdf

# Quick markdown merge (for sharing)
./cust-run-config.sh export markdown section FP \
    --no-toc --no-metadata

# Different page sizes
./cust-run-config.sh export pdf vault --page-size Letter
```

**Default output paths:**
```
./exports/export_<target>_<timestamp>.pdf
./exports/export_<target>_<timestamp>.html
./exports/export_<target>_<timestamp>.md
./exports/report_<customer>_<template>_<timestamp>.pdf
```

---

## Git-Sync Command

### `git-sync`

Automatic git synchronization for vault changes. Commit and push vault modifications automatically.

**Use cases:**
- Keep vault changes backed up to a remote repository
- Sync vault across multiple machines
- Maintain version history of your notes

```bash
# Show sync status
./cust-run-config.sh git-sync status

# Sync now (commit + push)
./cust-run-config.sh git-sync now

# Watch for changes (foreground)
./cust-run-config.sh git-sync watch --interval 120

# Configure git-sync settings
./cust-run-config.sh git-sync config

# Enable automatic sync
./cust-run-config.sh git-sync enable cron

# Initialize vault as git repo
./cust-run-config.sh git-sync init https://github.com/user/vault.git
```

### Git-Sync Subcommands

| Subcommand | Description |
|------------|-------------|
| `status` | Show git sync status and pending changes |
| `now`, `sync` | Sync immediately (commit + push) |
| `watch` | Watch for changes and sync continuously |
| `config` | Configure git-sync settings interactively |
| `enable <method>` | Enable auto-sync (`cron` or `systemd`) |
| `disable` | Disable auto-sync |
| `log [lines]` | Show sync history (default: 20 lines) |
| `init [url]` | Initialize vault as git repository |

### Git-Sync Options

| Option | Description |
|--------|-------------|
| `-i, --interval <sec>` | Sync interval for watch mode (default: 300) |
| `-q, --quiet` | Suppress output (for cron jobs) |

### Auto-Sync Methods

| Method | Description |
|--------|-------------|
| `cron` | Uses crontab for periodic sync |
| `systemd` | Uses systemd user timer (Linux only) |

### Commit Message Variables

| Variable | Description |
|----------|-------------|
| `{{DATE}}` | Current date (YYYY-MM-DD) |
| `{{TIME}}` | Current time (HH:MM:SS) |
| `{{USER}}` | Current username |
| `{{HOSTNAME}}` | Machine hostname |

### Configuration

Git-sync settings are stored in:
```
~/.config/autovault/git-sync.conf
```

Settings include:
- Sync interval
- Commit message template
- Remote name and branch
- Push/pull behavior
- Notification preferences

### Setup Guide

```bash
# 1. Initialize git in your vault (if not already done)
./cust-run-config.sh git-sync init

# 2. Add remote repository
cd /path/to/vault
git remote add origin https://github.com/user/vault.git

# 3. Configure sync settings
./cust-run-config.sh git-sync config

# 4. Enable automatic sync
./cust-run-config.sh git-sync enable cron
```

### Examples

```bash
# Watch and sync every 2 minutes
./cust-run-config.sh git-sync watch -i 120

# View last 50 sync events
./cust-run-config.sh git-sync log 50

# Enable systemd timer (Linux)
./cust-run-config.sh git-sync enable systemd

# Quick manual sync
./cust-run-config.sh git-sync now
```

---

## Nmap Integration Command

### `nmap`

Import Nmap scan results into customer folders. Parses XML and grepable formats to generate structured Markdown reports.

```bash
# Import Nmap XML scan for a customer
./cust-run-config.sh nmap import scan.xml --customer CUST-001

# Import grepable format
./cust-run-config.sh nmap import scan.gnmap -c CUST-002 --format gnmap

# Parse and preview without importing
./cust-run-config.sh nmap parse scan.xml

# List available templates
./cust-run-config.sh nmap templates list

# Custom output directory
./cust-run-config.sh nmap import scan.xml -c CUST-001 -o /path/to/output
```

### Nmap Subcommands

| Subcommand | Description |
|------------|-------------|
| `import` | Import Nmap scan into customer folder |
| `parse` | Parse and display scan results (preview) |
| `templates` | Manage Nmap report templates |

### Nmap Options

| Option | Description |
|--------|-------------|
| `-c, --customer <ID>` | Target customer ID (required for import) |
| `-f, --format <type>` | Input format: `xml` (default), `gnmap` |
| `-o, --output-dir <path>` | Custom output directory |
| `--raw` | Preserve raw scan data |
| `--no-summary` | Skip summary generation |
| `-q, --quiet` | Suppress output |

### Supported Input Formats

| Format | Extension | Description |
|--------|-----------|-------------|
| XML | `.xml` | Full Nmap XML output (`-oX`) |
| Grepable | `.gnmap` | Grepable output (`-oG`) |

### Generated Files

When importing Nmap scans, the following structure is created:

```
CUST-001/
├── Recon/
│   ├── Nmap/
│   │   ├── 2024-01-15_scan-summary.md     # Markdown report
│   │   ├── 2024-01-15_scan.xml            # Original file (if --raw)
│   │   └── hosts/
│   │       ├── 192.168.1.1.md             # Per-host details
│   │       ├── 192.168.1.2.md
│   │       └── ...
```

### Markdown Report Contents

Generated reports include:

- **Scan metadata**: Date, targets, command used
- **Hosts summary**: Table of all discovered hosts
- **Open ports**: Per-host port/service listings
- **Service versions**: Detected software versions
- **OS detection**: Operating system fingerprinting
- **Scripts output**: NSE script results (if any)
- **Dataview queries**: For Obsidian integration

### Examples

```bash
# Basic import
./cust-run-config.sh nmap import network-scan.xml -c CUST-001

# Import with raw file preservation
./cust-run-config.sh nmap import pentest.xml -c CUST-002 --raw

# Parse only (dry run)
./cust-run-config.sh nmap parse quick-scan.gnmap -f gnmap

# Quiet mode for scripting
./cust-run-config.sh nmap import scan.xml -c CUST-001 -q

# Show available templates
./cust-run-config.sh nmap templates list
```

### Integration with Obsidian

The generated Markdown files include:

- **Frontmatter**: YAML metadata for Dataview
- **Tags**: `#nmap`, `#recon`, `#scan`
- **Links**: Internal links to host files
- **Dataview blocks**: Queries for port/service tables

Example Dataview query in generated files:

```dataview
TABLE port, service, version
FROM "CUST-001/Recon/Nmap/hosts"
WHERE file.name != this.file.name
SORT port ASC
```

---

## Burp Suite Integration Command

### `burp`

Import Burp Suite scan results into customer folders. Parses XML exports and generates structured Markdown vulnerability reports.

```bash
# Import Burp scan for a customer
./cust-run-config.sh burp import burp-scan.xml --customer CUST-001

# Import only High and Medium findings
./cust-run-config.sh burp import scan.xml -c CUST-002 --severity Medium

# Parse and preview without importing
./cust-run-config.sh burp parse burp-export.xml

# List available templates
./cust-run-config.sh burp templates list

# Keep original XML file
./cust-run-config.sh burp import scan.xml -c CUST-001 --raw
```

### Burp Subcommands

| Subcommand | Description |
|------------|-------------|
| `import` | Import Burp scan into customer folder |
| `parse` | Parse and display findings (preview) |
| `templates` | Manage Burp report templates |

### Burp Options

| Option | Description |
|--------|-------------|
| `-c, --customer <ID>` | Target customer ID (required for import) |
| `--severity <level>` | Filter by minimum: `High`, `Medium`, `Low`, `Info` |
| `-o, --output-dir <path>` | Custom output directory |
| `--raw` | Preserve original XML file |
| `--no-summary` | Skip summary generation |
| `-q, --quiet` | Suppress output |

### Severity Levels

| Level | Icon | Description |
|-------|------|-------------|
| High | 🔴 | Critical vulnerabilities |
| Medium | 🟠 | Significant issues |
| Low | 🟡 | Minor concerns |
| Info | 🔵 | Informational findings |

### Generated Files

When importing Burp scans, the following structure is created:

```
CUST-001/
├── Vulnerabilities/
│   ├── Burp/
│   │   ├── 2024-01-15_burp-summary.md     # Overview report
│   │   ├── burp-scan.xml                   # Original (if --raw)
│   │   └── findings/
│   │       ├── sql-injection.md            # Per-vulnerability
│   │       ├── xss-reflected.md
│   │       ├── csrf.md
│   │       └── ...
```

### Burp Export Instructions

1. In Burp Suite: **Target** > **Site map** > Right-click target
2. Select: **Issues** > **Report issues**
3. Choose **XML** format
4. Enable "**Base64-encode requests and responses**" for full data
5. Save as `.xml` file

### Markdown Report Contents

Generated reports include:

- **Frontmatter**: YAML metadata for Dataview
- **Severity badge**: Visual indicator (🔴🟠🟡🔵)
- **Issue details**: Background, remediation guidance
- **HTTP Request/Response**: Decoded evidence
- **Status checklist**: Confirmed/Exploited/Reported/Fixed/Verified
- **Dataview queries**: For vulnerability tracking

### Examples

```bash
# Basic import
./cust-run-config.sh burp import webapp-scan.xml -c CUST-001

# High severity only
./cust-run-config.sh burp import pentest.xml -c CUST-002 --severity High

# Preview findings
./cust-run-config.sh burp parse quick-scan.xml

# Quiet mode for scripting
./cust-run-config.sh burp import scan.xml -c CUST-001 -q

# Show templates
./cust-run-config.sh burp templates list
```

### Integration with Obsidian

The generated Markdown files include Dataview queries for tracking:

```dataview
TABLE severity, confidence, host, path
FROM "CUST-001/Vulnerabilities/Burp"
WHERE severity = "High"
SORT file.name ASC
```

---

## Theme Command

### `theme`

Configure AutoVault's color theme and UI preferences.

```bash
# Show current theme settings
./cust-run-config.sh theme

# Set theme
./cust-run-config.sh theme set dark    # Dark terminal (default)
./cust-run-config.sh theme set light   # Light terminal
./cust-run-config.sh theme set auto    # Auto-detect

# Preview all themes
./cust-run-config.sh theme preview

# Interactive configuration
./cust-run-config.sh theme config

# Reset to defaults
./cust-run-config.sh theme reset
```

**Configuration file:** `~/.config/autovault/theme.conf`

**Environment variables:**

| Variable | Description |
|----------|-------------|
| `AUTOVAULT_THEME` | Override theme (dark/light/auto) |
| `AUTOVAULT_NOTIFY` | Enable notifications (true/false) |
| `NO_COLOR` | Disable all colors (standard) |

---

## Demo Command

### `demo`

Demonstrate AutoVault's UI components. Useful for testing themes and terminal compatibility.

```bash
# Run all demos
./cust-run-config.sh demo

# Progress bar demonstration
./cust-run-config.sh demo progress

# Spinner/loading animation
./cust-run-config.sh demo spinner

# Theme switching preview
./cust-run-config.sh demo theme

# Interactive menu selection
./cust-run-config.sh demo menu

# Desktop notifications
./cust-run-config.sh demo notify

# Box and section formatting
./cust-run-config.sh demo box
```

---

## Multi-Vault Management

### `vaults`

Manage multiple vault profiles. Switch between different Obsidian vaults.

```bash
# List all vault profiles
./cust-run-config.sh vaults list

# Add a new vault profile
./cust-run-config.sh vaults add work ~/Documents/WorkVault
./cust-run-config.sh vaults add personal ~/Obsidian/Personal

# Switch to a different vault
./cust-run-config.sh vaults switch work
./cust-run-config.sh vaults switch personal

# Show current active vault
./cust-run-config.sh vaults current

# Show vault details
./cust-run-config.sh vaults info work

# Remove a vault profile (doesn't delete files)
./cust-run-config.sh vaults remove old-project
```

**Configuration:** `~/.config/autovault/vaults.json`

---

## Plugin System

### `plugins`

Extend AutoVault with custom plugins.

```bash
# List installed plugins
./cust-run-config.sh plugins list

# Show plugin details
./cust-run-config.sh plugins info my-plugin

# Enable/disable plugins
./cust-run-config.sh plugins enable my-plugin
./cust-run-config.sh plugins disable my-plugin

# Create a new plugin from template
./cust-run-config.sh plugins create my-new-plugin

# Run a plugin command
./cust-run-config.sh plugins run my-plugin my-command arg1 arg2
```

**Plugin events:**

| Event | Triggered When |
|-------|----------------|
| `on-init` | AutoVault starts |
| `on-customer-create` | After customer creation |
| `on-customer-remove` | Before customer removal |
| `on-template-apply` | After templates applied |
| `on-backup-create` | After backup created |
| `on-vault-switch` | When switching vaults |

**Plugin structure:**
```
plugins/
  my-plugin/
    plugin.json       # Metadata
    init.sh           # Initialization
    on-customer-create.sh  # Event handler
    commands/
      my-command.sh   # Custom command
```

---

## Encryption

### `encrypt`

Encrypt and decrypt sensitive notes. Supports `age` (recommended) or GPG.

```bash
# Initialize encryption (generate keys)
./cust-run-config.sh encrypt init
./cust-run-config.sh encrypt init --password  # Use password instead of keyfile

# Show encryption status
./cust-run-config.sh encrypt status

# Encrypt a file or folder
./cust-run-config.sh encrypt encrypt path/to/secret.md
./cust-run-config.sh encrypt encrypt path/to/folder/

# Decrypt
./cust-run-config.sh encrypt decrypt path/to/secret.md.age

# Lock all _private folders (encrypt)
./cust-run-config.sh encrypt lock

# Unlock all _private folders (decrypt)
./cust-run-config.sh encrypt unlock
```

**Backends:**

| Backend | Description |
|---------|-------------|
| `age` | Modern, simple encryption (recommended) |
| `gpg` | Traditional GPG encryption |

**Install age:** `brew install age` or `apt install age`

---

## Examples

```bash
# Initial setup
./cust-run-config.sh config
./cust-run-config.sh vault init

# Enable shell completions and create alias
./cust-run-config.sh completions install
./cust-run-config.sh alias install av

# Now you can use 'av' instead of './cust-run-config.sh'
av status
av customer add 42 --create
./cust-run-config.sh customer add 42 --create
./cust-run-config.sh templates apply

# Preview cleanup
./cust-run-config.sh --dry-run cleanup

# Verbose structure creation
./cust-run-config.sh -v structure

# Update templates after editing templates.json
./cust-run-config.sh templates sync
./cust-run-config.sh templates apply

# Multi-vault workflow
av vaults add work ~/Work/Vault
av vaults add personal ~/Personal/Vault
av vaults switch work
av status

# Encrypt sensitive notes before pushing
av encrypt lock
git commit -am "Update notes"
git push
av encrypt unlock
```
