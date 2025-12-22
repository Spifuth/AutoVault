# Changelog

All notable changes to AutoVault will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased] - Phase 2.1

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

## [2.3.0] - 2024-12-21

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

## [2.2.0] - 2024-12-20

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

## [2.1.0] - 2024-12-15

### Added
- Interactive configuration wizard (`config` command)
- Template preview (`templates preview`)
- Backup management improvements

### Changed
- Enhanced test suite (58 tests)
- Improved CI/CD pipeline

## [2.0.0] - 2024-12-01

### Added
- Complete rewrite with modular architecture
- Library system (`bash/lib/*.sh`)
- Comprehensive help system
- Obsidian plugin configuration (`vault plugins`)

### Changed
- New CLI structure with subcommands
- JSON-based configuration

## [1.0.0] - 2024-11-01

### Added
- Initial release
- Basic vault structure creation
- Customer and section management
- Template system
