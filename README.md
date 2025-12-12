# AutoVault

Helper scripts to create, template, verify, and clean a "Run" workspace in an Obsidian vault. Each customer gets a `CUST-XXX` folder with section subfolders, index files, and a global `Run-Hub.md` linking to every customer.

## Features

- **Structure generation** – Creates customer folders (`CUST-001`, `CUST-002`, …) with configurable section subfolders and a central `Run-Hub.md`
- **Template application** – Applies Markdown templates with placeholder substitution (`{{CUST_CODE}}`, `{{SECTION}}`, `{{NOW_UTC}}`, `{{NOW_LOCAL}}`)
- **Verification** – Validates folder structure, index files, and hub links
- **Cleanup** – Removes customer folders (protected by safety flags)
- **Cross-platform** – Parallel implementations in Bash and PowerShell

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

| Tool | Version | Notes |
|------|---------|-------|
| PowerShell | 7+ | `pwsh` must be in PATH |
| Bash | 4+ | For the orchestrator on Linux/macOS |
| jq | any | Required for JSON parsing in Bash |
| Python 3 | any | Used to generate config JSON |

## Project Structure

```
AutoVault/
├── cust-run-config.sh       # Bash orchestrator (Linux/macOS)
├── cust-run-config.ps1      # PowerShell config loader
├── config/
│   └── cust-run-config.json # Shared configuration (auto-generated)
├── bash/
│   ├── New-CustRunStructure.sh
│   ├── Apply-CustRunTemplates.sh
│   ├── Test-CustRunStructure.sh
│   └── Cleanup-CustRunStructure.sh
└── powershell/
    ├── New-CustRunStructure.ps1
    ├── Apply-CustRunTemplates.ps1
    ├── Test-CustRunStructure.ps1
    └── Cleanup-CustRunStructure.ps1
```

## Configuration

### 1. Edit the orchestrator script

Open `cust-run-config.sh` (or `cust-run-config.ps1` on Windows) and set:

| Variable | Description | Default |
|----------|-------------|---------|
| `VAULT_ROOT` | Absolute path to your Obsidian vault | `D:\Obsidian\Work-Vault` |
| `CUSTOMER_ID_WIDTH` | Zero-padding width for customer IDs | `3` |
| `CUSTOMER_IDS` | Array of numeric customer codes | `(2 4 5 7 10 11 12 14 15 18 25 27 29 30)` |
| `SECTIONS` | Section folder names | `(FP RAISED INFORMATIONS DIVERS)` |
| `TEMPLATE_RELATIVE_ROOT` | Relative path to templates folder | `_templates\Run` |

### 2. Generate the config file

Run the orchestrator once to create/update `config/cust-run-config.json`:

```bash
./cust-run-config.sh structure
```

This JSON file is the single source of truth shared by both Bash and PowerShell scripts.

### 3. Create template files

Place your Markdown templates in `<VAULT_ROOT>/_templates/Run/`:

| Template | Purpose |
|----------|---------|
| `CUST-Root-Index.md` | Customer root index |
| `CUST-Section-FP-Index.md` | FP section index |
| `CUST-Section-RAISED-Index.md` | RAISED section index |
| `CUST-Section-INFORMATIONS-Index.md` | INFORMATIONS section index |
| `CUST-Section-DIVERS-Index.md` | DIVERS section index |

**Supported placeholders:**

| Placeholder | Replaced with |
|-------------|---------------|
| `{{CUST_CODE}}` | Customer code (e.g., `CUST-002`) |
| `{{SECTION}}` | Section name (e.g., `FP`, `RAISED`) |
| `{{NOW_UTC}}` | ISO 8601 UTC datetime |
| `{{NOW_LOCAL}}` | ISO 8601 local datetime |

## Usage

### Orchestrator (recommended)

```bash
# Create/refresh folders and Run-Hub.md
./cust-run-config.sh structure

# Apply markdown templates to all indexes
./cust-run-config.sh templates

# Verify the structure and hub links
./cust-run-config.sh test

# Delete customer folders (requires enabling deletion flag)
./cust-run-config.sh cleanup
```

Command aliases:

| Command | Alias |
|---------|-------|
| `structure` | `new` |
| `templates` | `apply` |
| `test` | `verify` |

### Environment variable overrides

Configuration can be overridden via environment variables:

```bash
VAULT_ROOT="/path/to/vault" CUSTOMER_IDS="1 2 3" ./cust-run-config.sh structure
```

PowerShell equivalents use the `CUST_` prefix:

| Bash | PowerShell |
|------|------------|
| `VAULT_ROOT` | `$env:CUST_VAULT_ROOT` |
| `CUSTOMER_ID_WIDTH` | `$env:CUST_CUSTOMER_ID_WIDTH` |
| `CUSTOMER_IDS` | `$env:CUST_CUSTOMER_IDS` |
| `SECTIONS` | `$env:CUST_SECTIONS` |
| `TEMPLATE_RELATIVE_ROOT` | `$env:CUST_TEMPLATE_RELATIVE_ROOT` |

## Safety Notes

### Cleanup protection

Cleanup is **disabled by default** to prevent accidental data loss. To enable deletions:

- **PowerShell**: Set `$EnableDeletion = $true` in `Cleanup-CustRunStructure.ps1`
- **Bash**: Set `ENABLE_DELETION=true` in `Cleanup-CustRunStructure.sh`

To also remove `Run-Hub.md`:

- **PowerShell**: Set `$RemoveHub = $true`
- **Bash**: Set `REMOVE_HUB=true`

### Direct script usage

Individual scripts in `bash/` and `powershell/` can be run directly after setting the required environment variables. The scripts will attempt to source configuration from `cust-run-config.sh` or fall back to `cust-run-config.json`.

## License

MIT
