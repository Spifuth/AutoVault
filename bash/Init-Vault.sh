#!/usr/bin/env bash
#===============================================================================
#
#  SCRIPT NAME:    Init-Vault.sh
#  DESCRIPTION:    Initialize a new AutoVault setup from scratch
#                  Creates vault directory, default config, and basic structure
#
#  USAGE:          ./Init-Vault.sh [--path <path>] [--profile <name>] [--force]
#
#  OPTIONS:        --path <path>      Path for the new vault (default: current dir)
#                  --profile <name>   Profile template (pentest|audit|bugbounty|minimal)
#                  --force            Overwrite existing configuration
#                  --no-structure     Skip creating initial structure
#
#  AUTHOR:         AutoVault Project
#  VERSION:        2.3.0
#
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"

#--------------------------------------
# DEFAULTS
#--------------------------------------
VAULT_PATH=""
PROFILE="minimal"
FORCE=false
CREATE_STRUCTURE=true

#--------------------------------------
# PROFILES
#--------------------------------------
declare -A PROFILES

PROFILES[minimal]='
{
  "VaultRoot": "{{VAULT_PATH}}",
  "CustomerPrefix": "Client",
  "CustomerIdWidth": 3,
  "CustomerIds": [],
  "Sections": ["Notes", "Tasks"],
  "TemplateRelativeRoot": "_templates/run",
  "Options": {
    "HooksEnabled": false,
    "BackupPath": "backups",
    "BackupRetention": 30,
    "ColorsEnabled": true
  }
}'

PROFILES[pentest]='
{
  "VaultRoot": "{{VAULT_PATH}}",
  "CustomerPrefix": "CUST",
  "CustomerIdWidth": 3,
  "CustomerIds": [],
  "Sections": [
    "Recon",
    "Enumeration", 
    "Exploitation",
    "PostExploit",
    "Pivoting",
    "Reporting"
  ],
  "TemplateRelativeRoot": "_templates/run",
  "Options": {
    "HooksEnabled": true,
    "HooksPath": "hooks",
    "BackupPath": "backups",
    "BackupRetention": 90,
    "ColorsEnabled": true
  }
}'

PROFILES[audit]='
{
  "VaultRoot": "{{VAULT_PATH}}",
  "CustomerPrefix": "Audit",
  "CustomerIdWidth": 3,
  "CustomerIds": [],
  "Sections": [
    "Scope",
    "Planning",
    "Documentation-Review",
    "Technical-Assessment",
    "Evidence",
    "Findings",
    "Recommendations"
  ],
  "TemplateRelativeRoot": "_templates/run",
  "Options": {
    "HooksEnabled": true,
    "HooksPath": "hooks",
    "BackupPath": "backups",
    "BackupRetention": 365,
    "ColorsEnabled": true
  }
}'

PROFILES[bugbounty]='
{
  "VaultRoot": "{{VAULT_PATH}}",
  "CustomerPrefix": "Program",
  "CustomerIdWidth": 3,
  "CustomerIds": [],
  "Sections": [
    "Recon",
    "Web",
    "API",
    "Mobile",
    "Findings",
    "Submissions"
  ],
  "TemplateRelativeRoot": "_templates/run",
  "Options": {
    "HooksEnabled": true,
    "HooksPath": "hooks",
    "BackupPath": "backups",
    "BackupRetention": 180,
    "ColorsEnabled": true
  }
}'

#--------------------------------------
# LIST PROFILES
#--------------------------------------
list_profiles() {
  echo ""
  echo -e "${BOLD}Available Profiles${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  
  echo -e "${GREEN}minimal${NC} (default)"
  echo "  Basic setup for simple note-taking"
  echo "  Sections: Notes, Tasks"
  echo "  Backup retention: 30 days"
  echo ""
  
  echo -e "${GREEN}pentest${NC}"
  echo "  Penetration testing workflow"
  echo "  Sections: Recon, Enumeration, Exploitation, PostExploit, Pivoting, Reporting"
  echo "  Backup retention: 90 days"
  echo ""
  
  echo -e "${GREEN}audit${NC}"
  echo "  Security audit workflow"
  echo "  Sections: Scope, Planning, Documentation-Review, Technical-Assessment,"
  echo "            Evidence, Findings, Recommendations"
  echo "  Backup retention: 365 days"
  echo ""
  
  echo -e "${GREEN}bugbounty${NC}"
  echo "  Bug bounty hunting workflow"
  echo "  Sections: Recon, Web, API, Mobile, Findings, Submissions"
  echo "  Backup retention: 180 days"
  echo ""
  
  echo -e "${DIM}Usage: $(basename "$0") --profile <name>${NC}"
  echo ""
}

#--------------------------------------
# USAGE
#--------------------------------------
usage() {
  cat << EOF
${BOLD}USAGE${NC}
    $(basename "$0") [OPTIONS]

${BOLD}DESCRIPTION${NC}
    Initialize a new AutoVault setup from scratch.
    Creates vault directory, configuration files, and optional initial structure.

${BOLD}OPTIONS${NC}
    --path <path>       Path for the vault (default: ./vault)
    --profile <name>    Configuration profile:
                          ${GREEN}minimal${NC}   - Basic setup with minimal sections
                          ${GREEN}pentest${NC}   - Penetration testing workflow
                          ${GREEN}audit${NC}     - Security audit workflow
                          ${GREEN}bugbounty${NC} - Bug bounty hunting workflow
    --list-profiles     Show available profiles with details
    --force             Overwrite existing configuration
    --no-structure      Skip creating initial directory structure
    -h, --help          Show this help message

${BOLD}EXAMPLES${NC}
    # Initialize in current directory with default profile
    $(basename "$0")

    # Initialize pentest vault in specific directory
    $(basename "$0") --path ~/Documents/PentestVault --profile pentest

    # Initialize minimal setup without structure
    $(basename "$0") --profile minimal --no-structure

EOF
}

#--------------------------------------
# PARSE ARGUMENTS
#--------------------------------------
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --path)
        VAULT_PATH="$2"
        shift 2
        ;;
      --list-profiles)
        list_profiles
        exit 0
        ;;
      --profile)
        PROFILE="$2"
        if [[ -z "${PROFILES[$PROFILE]:-}" ]]; then
          log_error "Unknown profile: $PROFILE"
          log_info "Available profiles: minimal, pentest, audit, bugbounty"
          exit 1
        fi
        shift 2
        ;;
      --force)
        FORCE=true
        shift
        ;;
      --no-structure)
        CREATE_STRUCTURE=false
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done

  # Default vault path
  if [[ -z "$VAULT_PATH" ]]; then
    VAULT_PATH="$(pwd)/vault"
  fi

  # Expand path
  VAULT_PATH="$(realpath -m "$VAULT_PATH")"
}

#--------------------------------------
# CREATE CONFIG
#--------------------------------------
create_config() {
  local config_dir="$SCRIPT_DIR/../config"
  local config_file="$config_dir/cust-run-config.json"

  # Check existing config
  if [[ -f "$config_file" ]] && [[ "$FORCE" != "true" ]]; then
    log_warn "Configuration already exists: $config_file"
    echo ""
    read -p "Overwrite existing configuration? [y/N] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      log_info "Keeping existing configuration"
      return 0
    fi
  fi

  # Create config directory
  mkdir -p "$config_dir"

  # Generate config from profile
  local config_content="${PROFILES[$PROFILE]}"
  config_content="${config_content//\{\{VAULT_PATH\}\}/$VAULT_PATH}"

  # Add metadata
  local timestamp
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  config_content=$(echo "$config_content" | jq --arg ts "$timestamp" '. + {metadata: {version: "2.3.0", created: $ts, profile: "'"$PROFILE"'"}}')

  # Write config
  echo "$config_content" | jq '.' > "$config_file"
  log_success "Created configuration: $config_file"
  log_info "Profile: $PROFILE"
}

#--------------------------------------
# CREATE VAULT DIRECTORY
#--------------------------------------
create_vault_dir() {
  if [[ -d "$VAULT_PATH" ]]; then
    log_info "Vault directory already exists: $VAULT_PATH"
    return 0
  fi

  log_info "Creating vault directory: $VAULT_PATH"
  mkdir -p "$VAULT_PATH"
  log_success "Created vault directory"
}

#--------------------------------------
# CREATE TEMPLATES DIRECTORY
#--------------------------------------
create_templates() {
  local templates_dir="$VAULT_PATH/_templates"
  
  if [[ -d "$templates_dir" ]]; then
    log_info "Templates directory already exists"
    return 0
  fi

  log_info "Creating templates directory..."
  mkdir -p "$templates_dir/run/root"
  mkdir -p "$templates_dir/run/section"
  mkdir -p "$templates_dir/obsidian"

  # Create basic main template
  cat > "$templates_dir/run/root/tp_main.md" << 'TEMPLATE'
# {{CUSTOMER_NAME}}

> **ID:** {{CUSTOMER_ID}}
> **Created:** {{DATE}}

## Overview

[Project overview and objectives]

## Sections

{{#each SECTIONS}}
- [ ] [[{{this}}]]
{{/each}}

## Notes

---
*Generated by AutoVault on {{DATETIME}}*
TEMPLATE

  # Create basic section template
  cat > "$templates_dir/run/section/tp_notes.md" << 'TEMPLATE'
# {{SECTION}} - Notes

## Objectives
- 

## Observations
- 

## Actions
- [ ] 

---
*{{CUSTOMER_NAME}} | {{SECTION}} | {{DATE}}*
TEMPLATE

  log_success "Created templates directory with basic templates"
}

#--------------------------------------
# CREATE INITIAL STRUCTURE
#--------------------------------------
create_structure() {
  if [[ "$CREATE_STRUCTURE" != "true" ]]; then
    log_info "Skipping initial structure creation (--no-structure)"
    return 0
  fi

  log_info "Creating initial vault structure..."

  # Create common directories
  mkdir -p "$VAULT_PATH/_archive"
  mkdir -p "$VAULT_PATH/_resources"

  # Create README
  cat > "$VAULT_PATH/README.md" << EOF
# AutoVault

This vault is managed by [AutoVault](https://github.com/Spifuth/AutoVault).

## Structure

- \`_templates/\` - Template files
- \`_archive/\` - Archived clients
- \`_resources/\` - Shared resources
- \`CustRun-*/\` - Client folders

## Quick Commands

\`\`\`bash
# Add a new client
cust-run-config.sh customer add <id> "Client Name"

# List clients
cust-run-config.sh customer list

# Show status
cust-run-config.sh status
\`\`\`

## Profile

This vault was initialized with the **$PROFILE** profile.

---
*Initialized on $(date +%Y-%m-%d)*
EOF

  log_success "Created initial structure"
}

#--------------------------------------
# PRINT SUMMARY
#--------------------------------------
print_summary() {
  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${NC}                                                              ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}    ${GREEN}✓${NC} ${BOLD}AutoVault Initialized Successfully!${NC}                     ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}                                                              ${CYAN}║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${BOLD}Configuration:${NC}"
  echo -e "  Profile:     ${GREEN}$PROFILE${NC}"
  echo -e "  Vault Path:  ${DIM}$VAULT_PATH${NC}"
  echo -e "  Config:      ${DIM}$SCRIPT_DIR/../config/cust-run-config.json${NC}"
  echo ""
  echo -e "${BOLD}Next steps:${NC}"
  echo -e "  1. Review configuration: ${CYAN}cust-run-config.sh validate${NC}"
  echo -e "  2. Add your first client: ${CYAN}cust-run-config.sh customer add 1 \"Client Name\"${NC}"
  echo -e "  3. Check status: ${CYAN}cust-run-config.sh status${NC}"
  echo ""
}

#--------------------------------------
# MAIN
#--------------------------------------
main() {
  parse_args "$@"

  echo ""
  log_info "Initializing AutoVault..."
  echo ""

  # Check for jq
  if ! command -v jq &> /dev/null; then
    log_error "jq is required but not installed"
    log_info "Install with: sudo apt install jq (or brew install jq)"
    exit 1
  fi

  create_vault_dir
  create_config
  create_templates
  create_structure
  print_summary
}

main "$@"
