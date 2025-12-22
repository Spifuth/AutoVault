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
```
