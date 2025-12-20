# Changelog

All notable changes to AutoVault will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
