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

## Examples

```bash
# Initial setup
./cust-run-config.sh config
./cust-run-config.sh vault init

# Enable shell completions
./cust-run-config.sh completions install

# Add a new customer with structure
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
