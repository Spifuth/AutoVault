# Changelog

All notable changes to AutoVault will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - Phase 5

### Planned
- Phase 5.1: Multi-vault Management (vault profiles, switching)
- Phase 5.2: Plugin System (custom automation hooks)
- Phase 5.3: Web UI Dashboard (optional)

---

## [2.8.0] - 2025-12-23 - Phase 4.3 (Burp Suite Integration)

### Added
- **Burp Suite Integration** (`burp`) - Import Burp Suite findings into customer folders
  - `burp import <file>` - Import XML scan into customer folder
  - `burp parse <file>` - Parse and preview findings
  - `burp templates` - Manage Burp report templates
  - XML export format support
  - Severity filtering (High/Medium/Low/Info)
  - Per-vulnerability Markdown files
  - HTTP request/response preservation (base64 decoded)
  - Status tracking checklist (Confirmed/Exploited/Reported/Fixed/Verified)
  - Dataview integration for vulnerability tracking

### Changed
- Test suite expanded to 160 tests (100% passing)
- Shell completions updated for burp command (Bash and Zsh)
- Help system updated with burp documentation
- COMMANDS.md updated with burp reference
- Phase 4.3 complete: Git-Sync + Nmap + Burp integrations

---

## [2.7.0] - 2025-12-23 - Phase 4.3 (Nmap Integration)

### Added
- **Nmap Integration** (`nmap`) - Import Nmap scan results into customer folders
  - `nmap import <file>` - Import XML or grepable scan into customer folder
  - `nmap parse <file>` - Parse and preview scan results
  - `nmap templates` - Manage Nmap report templates
  - XML format support (`-oX`)
  - Grepable format support (`-oG`/`-oN`)
  - Automatic Markdown report generation
  - Per-host detail files with port/service information
  - Dataview integration for Obsidian queries
  - Service version and OS detection parsing
  - NSE script output support

### Changed
- Test suite expanded to 151 tests (100% passing)
- Shell completions updated for nmap command (Bash and Zsh)
- Help system updated with nmap documentation
- COMMANDS.md updated with nmap reference

---

## [2.6.0] - 2025-12-23 - Phase 4.3 (Git-Sync)

### Added
- **Git Auto-Sync** (`git-sync`) - Automatic vault synchronization
  - `git-sync status` - Show sync status and pending changes
  - `git-sync now` - Sync immediately (commit + push)
  - `git-sync watch` - Watch for changes continuously
  - `git-sync config` - Configure sync settings
  - `git-sync enable` - Enable auto-sync (cron or systemd)
  - `git-sync disable` - Disable auto-sync
  - `git-sync log` - Show sync history
  - `git-sync init` - Initialize vault as git repository
  - Commit message templates with variables ({{DATE}}, {{TIME}}, etc.)
  - Desktop notifications on sync
  - Cron and systemd timer support

### Changed
- Test suite expanded to 142 tests (100% passing)
- Shell completions updated for git-sync command (Bash and Zsh)
- Help system updated with git-sync documentation
- COMMANDS.md updated with git-sync reference

---

## [2.5.0] - 2025-12-23 - Phase 4.2

### Added
- **Extended Packaging**
  - DEB package for Debian/Ubuntu (`packaging/debian/`)
  - RPM package for Fedora/RHEL (`packaging/rpm/`)
  - Build script (`packaging/build-packages.sh`)

### Changed
- Test suite expanded to 134 tests (100% passing)
- CI/CD pipeline updated for package builds
- Cross-platform compatibility fixes for macOS (mktemp, bash 5.x)

---

## [2.5.0] - 2025-12-22 - Phase 4.1

### Added
- **Export Command** (`export`) - Export vault content to various formats
  - `export pdf <target>` - Export to PDF (requires pandoc)
  - `export html <target>` - Export to static HTML
  - `export markdown <target>` - Export compiled Markdown
  - `export report <id>` - Generate professional client report
  - Template support: `default`, `pentest`, `audit`
  - Options: `--output`, `--template`, `--toc`, `--css`

### Dependencies
- pandoc (PDF/HTML export)
- wkhtmltopdf, weasyprint, or pdflatex (PDF engine)

---

## [2.4.0] - 2025-12-22 - Phase 3.2

### Added
- **Universal Installer** (`install.sh`)
  - curl-installable: `curl -fsSL ... | bash`
  - User mode (`--user`) and system mode
  - Automatic shell detection and completion install
- **Homebrew Formula** (`packaging/homebrew/autovault.rb`)
- **AUR Package** (`packaging/aur/PKGBUILD`)
- **Docker Support** (`Dockerfile`, `docker-compose.yml`)

---

## [2.4.0] - 2025-12-21 - Phase 3.1

### Added
- **GitHub Actions CI/CD**
  - Multi-OS testing (Ubuntu, macOS)
  - Automated release workflow on tags
  - Coverage reporting
- **Test Infrastructure**
  - 134 comprehensive tests
  - Coverage script (`tests/coverage.sh`)
  - Docker-based isolated testing

---

## [2.4.0] - 2025-12-21 - Phase 2.3

### Added
- **Multi-Vault Management** (`vaults`) - Manage multiple vault profiles
  - `vaults list` - List all configured vault profiles
  - `vaults add <name> <path>` - Add a new vault profile
  - `vaults remove <name>` - Remove a vault profile
  - `vaults switch <name>` - Switch to a different vault
  - `vaults current` - Show current active vault
  - `vaults info [name]` - Show detailed vault info
  - Configuration stored in `~/.config/autovault/vaults.json`

- **Plugin System** (`plugins`) - Extensible architecture
  - `plugins list` - List installed plugins
  - `plugins info <name>` - Show plugin details
  - `plugins enable/disable <name>` - Enable/disable plugins
  - `plugins create <name>` - Create new plugin from template
  - `plugins run <plugin> <cmd>` - Run plugin commands
  - Event-driven hooks (on-init, on-customer-create, etc.)
  - Plugin library (`bash/lib/plugins.sh`)

- **Encryption** (`encrypt`) - Encrypt sensitive notes
  - `encrypt init` - Initialize encryption (generate keys)
  - `encrypt encrypt/decrypt <path>` - Encrypt/decrypt files or folders
  - `encrypt status` - Show encryption status
  - `encrypt lock` - Encrypt all _private folders
  - `encrypt unlock` - Decrypt all _private folders
  - Supports `age` (recommended) and GPG backends

- **Dynamic Template Variables** (`bash/lib/template-vars.sh`)
  - Built-in variables: `{{DATE}}`, `{{TIME}}`, `{{USER}}`, `{{UUID}}`, etc.
  - Conditional syntax: `{{IF:VAR}}...{{ENDIF:VAR}}`
  - Custom variable registration
  - Template validation

---

## [2.4.0] - 2025-12-22 - Phase 2.2

### Added
- **UI Library** (`bash/lib/ui.sh`) - Comprehensive UI utilities
  - Theme system with dark/light/auto modes
  - Progress bars with customizable width and labels
  - Background spinners with cleanup on exit
  - Interactive menus with fzf fallback
  - Desktop notifications (Linux notify-send, macOS terminal-notifier)
  - Box formatting, tables, key-value output

- **Theme Command** (`theme`) - Configure UI appearance
  - `theme status` - Show current theme settings
  - `theme set <dark|light|auto>` - Set color theme
  - `theme preview` - Preview all themes
  - `theme config` - Interactive configuration
  - `theme reset` - Reset to defaults
  - Persistent config in `~/.config/autovault/theme.conf`

- **Demo Command** (`demo`) - UI component demonstrations
  - `demo progress` - Progress bar demo
  - `demo spinner` - Spinner/loading animation
  - `demo theme` - Theme switching preview
  - `demo menu` - Interactive menu selection
  - `demo notify` - Desktop notifications
  - `demo box` - Box and section formatting

### Changed
- **New-CustRunStructure.sh** - Now shows progress bar during customer creation
- **Doctor.sh** - Uses themed output and sends notifications on completion
- **Search-Vault.sh** - Shows spinner during search, notifies on results
- Help system updated with theme and demo documentation
- Shell completions updated for new commands (Bash and Zsh)

### Environment Variables
- `AUTOVAULT_THEME` - Override theme (dark/light/auto)
- `AUTOVAULT_NOTIFY` - Enable/disable desktop notifications (true/false)
- `NO_COLOR` - Disable all colors (standard)

---

## [2.4.0] - 2025-12-22 - Phase 2.1

### Added
- **Init Command** (`init`) - Initialize a new vault from scratch
  - Profile templates: `minimal`, `pentest`, `audit`, `bugbounty`
  - Creates vault directory, config files, templates, initial structure
  - Options: `--path`, `--profile`, `--force`, `--no-structure`

- **Doctor Command** (`doctor`) - Comprehensive diagnostic tool
  - Checks: dependencies, config, vault structure, permissions, disk space
  - Auto-fix mode with `--fix` flag
  - JSON output for scripting with `--json`
  - Detailed output with `--verbose`

- **Search Command** (`search`) - Search across all customers/notes
  - Text and regex search (`--regex`)
  - Filter by customer (`-c`), section (`-s`), file type (`-t`)
  - Context lines (`-C`), max results (`-m`)
  - Case-sensitive option, JSON output

- **Archive Command** (`archive`) - Archive a customer to compressed file
  - Formats: zip (default), tar, tar.gz, tar.bz2
  - Encryption support (zip only) with `--encrypt`
  - Remove after archive with `--remove`
  - Custom output path with `--output`

### Changed
- Help system reorganized with new categories (Management, Vault, Utilities)
- Shell completions updated for new commands (Bash and Zsh)

---

## [2.3.0] - 2025-12-21

### Added
- **Shell Completions Installer** - New `completions` command to install tab-completion
  - `completions status` - Show installation status
  - `completions install` - Install for current shell (auto-detect Bash/Zsh)
  - `completions uninstall` - Remove installed completions
  - Supports `--user` (default) and `--system` modes
  - Auto-detects Oh-My-Zsh for optimal installation path

- **System Alias Installer** - New `alias` command to create system aliases
  - `alias status` - Show installed aliases
  - `alias install [name]` - Create symlink or shell alias (default: `autovault`)
  - `alias uninstall` - Remove installed aliases
  - Supports custom names (`av`, `vault`, etc.)
  - Methods: `symlink` (recommended) or `alias` (shell rc file)

### Changed
- **Template Structure** - Templates now organized in sub-folders
  - `_templates/run/index/` - Index templates
  - `_templates/run/notes/` - Note templates (for Templater)
  - Updated `templates.json` to version 1.1 with `subFolders` configuration
- Template folder path changed from `_templates/Run` to `_templates/run` (lowercase)
- Main script now resolves symlinks to find its real location (required for alias feature)

---

## [2.2.0] - 2025-12-20

### Added
- **Remote Vault Sync** - Sync your vault with remote servers via SSH/rsync
  - `remote add/remove/list` - Manage remote servers
  - `remote push/pull` - Sync to/from remote
  - `remote test` - Test connection
  - `remote status` - Show sync status
- **Automation Hooks** - Run custom scripts before/after operations
  - `hooks list/init/test` - Manage hooks
  - Supported hooks: `pre-customer-remove`, `post-customer-remove`, `post-templates-apply`, `on-error`
- **Diff Mode** - Preview changes before applying (`--diff` flag)
- **Statistics Dashboard** - `stats` command for detailed vault analytics
- **Customer Export/Import** - Archive and restore customer folders
- **Customer Clone** - Duplicate existing customer structures
- **Shell Completions** - Bash and Zsh autocompletion
- **Version Check** - `--version` now checks for updates on GitHub

### Changed
- Centralized version management in `bash/lib/version.sh`
- Harmonized color variables in logging system
- Improved error handling with `on-error` hook support

### Removed
- TUI (Terminal User Interface) - Removed due to terminal compatibility issues

### Fixed
- Shell completion commands now match actual implemented features
- README version badge synchronized with code
- Documentation for rsync/ssh as optional dependencies

---

## [2.1.0] - 2025-12-15

### Added
- Interactive configuration wizard (`config` command)
- Template preview (`templates preview`)
- Backup management improvements

### Changed
- Enhanced test suite (58 tests)
- Improved CI/CD pipeline

---

## [2.0.0] - 2025-12-01

### Added
- Complete rewrite with modular architecture
- Library system (`bash/lib/*.sh`)
- Comprehensive help system
- Obsidian plugin configuration (`vault plugins`)

### Changed
- New CLI structure with subcommands
- JSON-based configuration

---

## [1.0.0] - 2025-11-01

### Added
- Initial release
- Basic vault structure creation
- Customer and section management
- Template system
