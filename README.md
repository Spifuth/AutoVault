<p align="center">
  <h1 align="center">🗄️ AutoVault</h1>
  <p align="center">
    <strong>Obsidian Vault Structure Manager</strong><br>
    Automate customer folder creation, templates, and organization in your Obsidian vault.
  </p>
  <p align="center">
    <img src="https://img.shields.io/badge/version-1.3-blue" alt="Version">
    <img src="https://img.shields.io/badge/bash-4%2B-green" alt="Bash 4+">
    <img src="https://img.shields.io/badge/ShellCheck-passing-brightgreen" alt="ShellCheck">
    <img src="https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20WSL-lightgrey" alt="Platform">
  </p>
</p>

---

## 📖 Overview

AutoVault helps you manage a structured "Run" workspace in your Obsidian vault. Each customer gets a \`CUST-XXX\` folder with configurable section subfolders, index files, and a central hub linking everything together.

### ✨ Features

| Feature | Description |
|---------|-------------|
| 📁 **Structure Generation** | Creates customer folders (\`CUST-001\`, \`CUST-002\`, …) with section subfolders |
| 📝 **Template Application** | Applies Markdown templates with placeholders (\`{{CUST_CODE}}\`, \`{{SECTION}}\`, etc.) |
| ✅ **Verification** | Validates folder structure, index files, and hub links |
| 🧹 **Cleanup** | Removes customer folders (protected by safety flags) |
| 👥 **Customer Management** | Add/remove customers dynamically |
| 📂 **Section Management** | Add/remove sections for all customers |
| 💾 **Backup Management** | Create, list, and restore configuration backups |
| 🔧 **Config Validation** | Validate JSON config with automatic fixes |

---

## 📂 Generated Structure

\`\`\`
📁 VaultRoot/
├── 📁 Run/
│   ├── 📁 CUST-001/
│   │   ├── 📄 CUST-001-Index.md
│   │   ├── 📁 CUST-001-FP/
│   │   │   └── 📄 CUST-001-FP-Index.md
│   │   ├── 📁 CUST-001-RAISED/
│   │   ├── 📁 CUST-001-INFORMATIONS/
│   │   └── 📁 CUST-001-DIVERS/
│   ├── 📁 CUST-002/
│   │   └── ...
│   └── ...
└── 📄 Run-Hub.md  ← Central navigation hub
\`\`\`

---

## 🚀 Quick Start

### 1. Install Dependencies

\`\`\`bash
# Check what's installed
./cust-run-config.sh requirements check

# Auto-install missing dependencies
./cust-run-config.sh requirements install
\`\`\`

**Required:** \`bash 4+\`, \`jq\`, \`python3\`

### 2. Configure

\`\`\`bash
./cust-run-config.sh config
\`\`\`

This launches an interactive wizard to set:
- **Vault path** – Your Obsidian vault location
- **Customer IDs** – List of customer numbers
- **Sections** – Folder categories (FP, RAISED, etc.)

### 3. Generate Structure

\`\`\`bash
./cust-run-config.sh structure   # Create folders
./cust-run-config.sh templates   # Apply templates
./cust-run-config.sh test        # Verify everything
\`\`\`

---

## 📋 Commands Reference

### Global Options

| Option | Description |
|--------|-------------|
| \`-v, --verbose\` | Enable debug output |
| \`-q, --quiet\` | Show errors only |
| \`--silent\` | Suppress all output |
| \`--no-color\` | Disable colored output |
| \`--dry-run\` | Preview changes without applying |
| \`-h, --help\` | Show help message |

### Configuration

\`\`\`bash
./cust-run-config.sh config      # Interactive wizard
./cust-run-config.sh validate    # Validate config file
./cust-run-config.sh status      # Show current status
\`\`\`

### Structure Management

\`\`\`bash
./cust-run-config.sh structure   # Create folder structure
./cust-run-config.sh templates   # Apply markdown templates
./cust-run-config.sh test        # Verify structure
./cust-run-config.sh cleanup     # Remove structure (⚠️ protected)
\`\`\`

### Customer Management

\`\`\`bash
./cust-run-config.sh customer add 31      # Add customer #31
./cust-run-config.sh customer remove 5    # Remove customer #5
./cust-run-config.sh customer list        # List all customers
\`\`\`

### Section Management

\`\`\`bash
./cust-run-config.sh section add URGENT   # Add new section
./cust-run-config.sh section remove OLD   # Remove section
./cust-run-config.sh section list         # List all sections
\`\`\`

### Backup Management

\`\`\`bash
./cust-run-config.sh backup list          # List backups
./cust-run-config.sh backup create        # Create backup
./cust-run-config.sh backup restore 1     # Restore backup #1
./cust-run-config.sh backup cleanup 10    # Keep only 10 most recent
\`\`\`

---

## ⚙️ Configuration

### Interactive Mode (Recommended)

\`\`\`bash
./cust-run-config.sh config
\`\`\`

\`\`\`
[INFO ] Interactive configuration mode
[INFO ] Press Enter to keep current/default values

Current configuration:
  1. VaultRoot:            /mnt/c/Users/You/Obsidian/Vault
  2. CustomerIdWidth:      3
  3. CustomerIds:          2 4 5 7 10 11 12
  4. Sections:             FP RAISED INFORMATIONS DIVERS
  5. TemplateRelativeRoot: _templates/Run

Vault root path [/mnt/c/Users/You/Obsidian/Vault]: _
\`\`\`

### Manual Configuration

Edit \`config/cust-run-config.json\`:

\`\`\`json
{
  "VaultRoot": "/path/to/your/vault",
  "CustomerIdWidth": 3,
  "CustomerIds": [1, 2, 3, 5, 8, 13],
  "Sections": ["FP", "RAISED", "INFORMATIONS", "DIVERS"],
  "TemplateRelativeRoot": "_templates/Run"
}
\`\`\`

| Parameter | Description | Example |
|-----------|-------------|---------|
| \`VaultRoot\` | Path to Obsidian vault | \`/mnt/c/Obsidian/Work\` |
| \`CustomerIdWidth\` | Zero-padding width | \`3\` → \`CUST-001\` |
| \`CustomerIds\` | Array of customer numbers | \`[1, 2, 5, 10]\` |
| \`Sections\` | Subfolder categories | \`["FP", "RAISED"]\` |
| \`TemplateRelativeRoot\` | Templates location | \`_templates/Run\` |

---

## 🖥️ Platform Support

### Linux / macOS

\`\`\`bash
# Install dependencies
sudo apt install jq python3    # Debian/Ubuntu
brew install jq python3        # macOS
\`\`\`

### Windows (WSL)

\`\`\`powershell
# Install WSL
wsl --install
\`\`\`

\`\`\`bash
# Inside WSL
sudo apt update && sudo apt install -y jq python3
\`\`\`

> 💡 **Tip:** Your Windows vault is accessible at \`/mnt/c/Users/YourName/...\`

---

## 🔒 Safety Features

### Hub File Preservation

When running \`structure\`, existing \`Run-Hub.md\` files are **never overwritten**. Delete manually to regenerate.

### Cleanup Protection

Cleanup is **disabled by default**. To enable:

\`\`\`bash
# In bash/Cleanup-CustRunStructure.sh
ENABLE_DELETION=true   # Allow folder deletion
REMOVE_HUB=true        # Also remove Run-Hub.md
\`\`\`

---

## 📝 Template System

### Generate Templates from JSON

\`\`\`bash
./Generate-CustRunTemplates.sh cust-run-templates.json
\`\`\`

### Template Format

\`\`\`json
{
  "Templates": [
    {
      "FileName": "CUST-Root-Index.md",
      "Content": "# {{CUST_CODE}}\n\nCreated: {{NOW_LOCAL}}"
    },
    {
      "FileName": "CUST-Section-FP-Index.md", 
      "Content": "# {{CUST_CODE}} | {{SECTION}}"
    }
  ]
}
\`\`\`

### Available Placeholders

| Placeholder | Description | Example |
|-------------|-------------|---------|
| \`{{CUST_CODE}}\` | Customer code | \`CUST-001\` |
| \`{{SECTION}}\` | Section name | \`FP\` |
| \`{{NOW_UTC}}\` | UTC timestamp | \`2024-12-18T15:30:00Z\` |
| \`{{NOW_LOCAL}}\` | Local timestamp | \`2024-12-18 16:30:00\` |

---

## 🏗️ Project Structure

\`\`\`
AutoVault/
├── 📄 cust-run-config.sh           # Main CLI (entry point)
├── 📄 Generate-CustRunTemplates.sh # Template generator
├── 📄 cust-run-templates.sample.json
│
├── 📁 config/
│   └── 📄 cust-run-config.json     # Configuration
│
├── 📁 backups/                     # Config backups
│
└── 📁 bash/
    ├── 📁 lib/
    │   ├── 📄 logging.sh           # Logging utilities
    │   └── 📄 config.sh            # Config management
    │
    ├── 📄 New-CustRunStructure.sh  # Create folders
    ├── 📄 Apply-CustRunTemplates.sh# Apply templates
    ├── 📄 Test-CustRunStructure.sh # Verify structure
    ├── 📄 Cleanup-CustRunStructure.sh
    ├── 📄 Manage-Customers.sh
    ├── 📄 Manage-Sections.sh
    ├── 📄 Manage-Backups.sh
    ├── 📄 Show-Status.sh
    ├── 📄 Validate-Config.sh
    └── 📄 Install-Requirements.sh
\`\`\`

---

## 🔍 Code Quality

| Practice | Implementation |
|----------|----------------|
| ✅ **Static Analysis** | All scripts pass [ShellCheck](https://www.shellcheck.net/) |
| ✅ **Consistent Logging** | Unified \`log_info\`, \`log_warn\`, \`log_error\`, \`log_debug\`, \`log_success\` |
| ✅ **Safe Defaults** | Destructive operations require explicit opt-in |
| ✅ **Path Handling** | Auto tilde expansion (\`~\`) and Windows path conversion |
| ✅ **Cleanup** | Trap handlers for temp file cleanup on interruption |

---

## 📜 Changelog

### v1.3 (December 2024)
- ✅ Full ShellCheck compliance
- ✅ Trap cleanup for temp files
- ✅ Standardized logging functions
- ✅ Windows path & tilde expansion
- ✅ Unified \`[y/N]\` confirmation prompts
- ✅ Removed PowerShell scripts (Bash only)
- ✅ Removed duplicate \`install-requirements.sh\`

### v1.1
- Initial modular architecture
- Customer and section management
- Backup system
- Configuration validation

---

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.

---

<p align="center">
  Made with ❤️ for Obsidian users
</p>
