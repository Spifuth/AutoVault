# 🏦 AutoVault

**Automated Obsidian vault structure manager for customer-centric operations (RUN/SOC workflows).**

AutoVault creates and maintains a standardized folder structure in your Obsidian vault, complete with templates and plugin configuration.

[![Version](https://img.shields.io/badge/version-2.3.0-blue)](https://github.com/Spifuth/AutoVault)
[![Bash](https://img.shields.io/badge/bash-4%2B-green)](https://www.gnu.org/software/bash/)
[![Tests](https://github.com/Spifuth/AutoVault/actions/workflows/tests.yml/badge.svg)](https://github.com/Spifuth/AutoVault/actions)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20WSL-lightgrey)](https://github.com/Spifuth/AutoVault)

---

## ⚡ Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/Spifuth/AutoVault.git
cd AutoVault

# 2. Configure your vault
./cust-run-config.sh config

# 3. Initialize everything
./cust-run-config.sh vault init

# 4. (Optional) Create a short alias and enable completions
./cust-run-config.sh alias install av
./cust-run-config.sh completions install

# Now use 'av' from anywhere!
av status
```

That's it! Your vault is ready with:
- 📁 Folder structure for all customers
- 📝 Templates applied to all index files
- ⚙️ Obsidian plugins configured (Templater, Dataview)
- 📊 Dynamic Run-Hub dashboard

---

## 📖 Documentation

| Document | Description |
|----------|-------------|
| [docs/COMMANDS.md](docs/COMMANDS.md) | Complete CLI reference |
| [docs/CONFIGURATION.md](docs/CONFIGURATION.md) | Configuration options |
| [docs/TEMPLATES.md](docs/TEMPLATES.md) | Template system guide |
| [docs/OBSIDIAN-SETUP.md](docs/OBSIDIAN-SETUP.md) | Obsidian plugin setup |

---

## 🗂️ What It Creates

```
YourVault/
├── Run-Hub.md                    # Dashboard with Dataview queries
├── Run/
│   ├── CUST-002/
│   │   ├── CUST-002-Index.md     # Customer hub
│   │   ├── CUST-002-FP/          # First Pass (routine checks)
│   │   ├── CUST-002-RAISED/      # Incidents/tickets
│   │   ├── CUST-002-INFORMATIONS/# Knowledge base
│   │   └── CUST-002-DIVERS/      # Misc/sandbox
│   ├── CUST-004/
│   └── ...
└── _templates/
    └── Run/                      # Auto-applied templates
```

---

## 🔧 Requirements

- **Bash 4+** (Linux, macOS, WSL)
- **jq** - JSON processor
- **Python 3** - For JSON/template operations
- **rsync** + **ssh** - For remote sync feature (optional)

```bash
# Check requirements
./cust-run-config.sh requirements check

# Auto-install (Debian/Ubuntu)
./cust-run-config.sh requirements install
```

---

## 🎯 Core Commands

```bash
# Configuration
./cust-run-config.sh config       # Interactive setup wizard
./cust-run-config.sh status       # Show current status

# Vault Management (recommended)
./cust-run-config.sh vault init   # Full setup: structure + templates + plugins

# Individual Operations
./cust-run-config.sh structure    # Create folder structure only
./cust-run-config.sh templates apply  # Apply templates to folders
./cust-run-config.sh vault plugins    # Configure Obsidian plugins

# System Integration
./cust-run-config.sh alias install av   # Create 'av' command
./cust-run-config.sh completions install  # Enable tab-completion
```

See [docs/COMMANDS.md](docs/COMMANDS.md) for the complete reference.

---

## 🔌 Obsidian Plugins

AutoVault auto-configures these plugins:

| Plugin | Purpose |
|--------|---------|
| **Templater** | Auto-apply templates when creating notes in CUST folders |
| **Dataview** | Dynamic queries in Run-Hub (open incidents, stats) |

Install them from Obsidian: `Settings → Community Plugins → Browse`

---

## 📁 Project Structure

```
AutoVault/
├── cust-run-config.sh          # Main CLI entry point
├── config/
│   ├── cust-run-config.json    # Your vault configuration
│   ├── templates.json          # All templates in JSON
│   └── obsidian-settings.json  # Plugin settings to apply
├── bash/
│   ├── lib/
│   │   ├── config.sh           # Config management
│   │   └── logging.sh          # Logging utilities
│   ├── New-CustRunStructure.sh
│   ├── Manage-Templates.sh
│   ├── Configure-ObsidianPlugins.sh
│   └── ...
├── docs/                       # Documentation
└── tests/                      # Automated tests
```

---

## 🧪 Testing

```bash
# Run all tests
./tests/run-tests.sh

# Test specific functionality
./cust-run-config.sh test       # Verify vault structure
./cust-run-config.sh validate   # Validate configuration
```

---

## 📜 License

MIT License - See [LICENSE](LICENSE) for details.

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing`)
3. Commit your changes
4. Push and open a Pull Request

---

Made with ❤️ for SOC/RUN teams who love organized documentation.
