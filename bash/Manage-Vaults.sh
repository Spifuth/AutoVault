#!/usr/bin/env bash
#===============================================================================
#
#  SCRIPT NAME:    Manage-Vaults.sh
#  DESCRIPTION:    Manage multiple AutoVault configurations (multi-vault)
#                  Switch between different vaults, list, add, remove profiles
#
#  USAGE:          ./Manage-Vaults.sh <subcommand> [options]
#
#  SUBCOMMANDS:    list        List all configured vaults
#                  add         Add a new vault profile
#                  remove      Remove a vault profile
#                  switch      Switch to a different vault
#                  current     Show current active vault
#                  info        Show detailed vault info
#
#  AUTHOR:         AutoVault Project
#  VERSION:        2.9.0
#
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"

# Source UI library if available
if [[ -f "$SCRIPT_DIR/lib/ui.sh" ]]; then
    source "$SCRIPT_DIR/lib/ui.sh"
    UI_AVAILABLE=true
else
    UI_AVAILABLE=false
fi

#--------------------------------------
# CONFIGURATION
#--------------------------------------
VAULTS_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/autovault"
VAULTS_FILE="$VAULTS_CONFIG_DIR/vaults.json"
CURRENT_VAULT_FILE="$VAULTS_CONFIG_DIR/current-vault"

#--------------------------------------
# USAGE
#--------------------------------------
usage() {
  cat << EOF
${BOLD:-}USAGE${NC:-}
    $(basename "$0") <SUBCOMMAND> [OPTIONS]

${BOLD:-}DESCRIPTION${NC:-}
    Manage multiple AutoVault vault profiles. Each profile is a separate
    configuration pointing to a different Obsidian vault.

${BOLD:-}SUBCOMMANDS${NC:-}
    list                    List all configured vault profiles
    add <name> <path>       Add a new vault profile
    remove <name>           Remove a vault profile
    switch <name>           Switch to a different vault profile
    current                 Show current active vault
    info [name]             Show detailed info about a vault

${BOLD:-}OPTIONS${NC:-}
    -h, --help              Show this help message

${BOLD:-}EXAMPLES${NC:-}
    # List all vaults
    $(basename "$0") list

    # Add a new vault
    $(basename "$0") add work ~/Documents/WorkVault
    $(basename "$0") add personal ~/Obsidian/Personal

    # Switch between vaults
    $(basename "$0") switch work
    $(basename "$0") switch personal

    # Show current vault
    $(basename "$0") current

    # Remove a vault profile
    $(basename "$0") remove old-project

${BOLD:-}CONFIGURATION${NC:-}
    Vaults config: $VAULTS_FILE
    Current vault: $CURRENT_VAULT_FILE

EOF
}

#--------------------------------------
# INIT CONFIG
#--------------------------------------
init_config() {
  mkdir -p "$VAULTS_CONFIG_DIR"
  
  if [[ ! -f "$VAULTS_FILE" ]]; then
    echo '{"vaults": {}}' > "$VAULTS_FILE"
  fi
}

#--------------------------------------
# LIST VAULTS
#--------------------------------------
cmd_list() {
  init_config
  
  local vaults_count
  vaults_count=$(jq '.vaults | length' "$VAULTS_FILE")
  
  if [[ "$vaults_count" -eq 0 ]]; then
    echo "No vault profiles configured."
    echo ""
    echo "Add one with: $(basename "$0") add <name> <path>"
    return 0
  fi
  
  local current_vault=""
  if [[ -f "$CURRENT_VAULT_FILE" ]]; then
    current_vault=$(cat "$CURRENT_VAULT_FILE")
  fi
  
  if [[ "$UI_AVAILABLE" == "true" ]]; then
    print_section "Vault Profiles"
    echo ""
  else
    echo "Vault Profiles:"
    echo "---------------"
  fi
  
  # List vaults
  local names
  names=$(jq -r '.vaults | keys[]' "$VAULTS_FILE")
  
  while IFS= read -r name; do
    local path
    local customers
    local created
    
    path=$(jq -r ".vaults[\"$name\"].path" "$VAULTS_FILE")
    customers=$(jq -r ".vaults[\"$name\"].customers // 0" "$VAULTS_FILE")
    created=$(jq -r ".vaults[\"$name\"].created // \"unknown\"" "$VAULTS_FILE")
    
    local marker=" "
    local status=""
    
    if [[ "$name" == "$current_vault" ]]; then
      marker="*"
      status="${GREEN:-}(active)${NC:-}"
    fi
    
    if [[ ! -d "$path" ]]; then
      status="${RED:-}(path not found)${NC:-}"
    fi
    
    if [[ "$UI_AVAILABLE" == "true" ]]; then
      printf "  %s %-15s %s %s\n" "$marker" "$name" "${THEME[muted]}$path${THEME[reset]}" "$status"
    else
      printf "  %s %-15s %s %s\n" "$marker" "$name" "$path" "$status"
    fi
  done <<< "$names"
  
  echo ""
  echo "* = current active vault"
}

#--------------------------------------
# ADD VAULT
#--------------------------------------
cmd_add() {
  local name="${1:-}"
  local path="${2:-}"
  
  if [[ -z "$name" ]]; then
    log_error "Vault name required"
    echo "Usage: $(basename "$0") add <name> <path>"
    exit 1
  fi
  
  if [[ -z "$path" ]]; then
    log_error "Vault path required"
    echo "Usage: $(basename "$0") add <name> <path>"
    exit 1
  fi
  
  # Validate name (alphanumeric + dash + underscore)
  if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    log_error "Invalid vault name. Use only letters, numbers, dashes, and underscores."
    exit 1
  fi
  
  init_config
  
  # Check if name exists
  local exists
  exists=$(jq -r ".vaults[\"$name\"] // empty" "$VAULTS_FILE")
  if [[ -n "$exists" ]]; then
    log_error "Vault profile '$name' already exists"
    echo "Use 'remove' first or choose a different name"
    exit 1
  fi
  
  # Expand path
  path="${path/#\~/$HOME}"
  path=$(realpath -m "$path")
  
  # Warn if path doesn't exist
  if [[ ! -d "$path" ]]; then
    log_warn "Path does not exist yet: $path"
    echo "The path will be created when you run 'init' on this vault."
  fi
  
  # Count existing customers if vault exists
  local customer_count=0
  if [[ -d "$path/Run" ]]; then
    customer_count=$(find "$path/Run" -maxdepth 1 -type d -name "CUST-*" 2>/dev/null | wc -l) || customer_count=0
  fi
  
  # Add to config
  local timestamp
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  
  local tmp_file
  tmp_file=$(mktemp)
  jq --arg name "$name" \
     --arg path "$path" \
     --arg created "$timestamp" \
     --argjson customers "$customer_count" \
     '.vaults[$name] = {path: $path, created: $created, customers: $customers}' \
     "$VAULTS_FILE" > "$tmp_file" && mv "$tmp_file" "$VAULTS_FILE"
  
  log_success "Added vault profile: $name"
  echo "  Path: $path"
  
  # If this is the first vault, set it as current
  local vault_count
  vault_count=$(jq '.vaults | length' "$VAULTS_FILE")
  if [[ "$vault_count" -eq 1 ]]; then
    echo "$name" > "$CURRENT_VAULT_FILE"
    log_info "Set as current vault (first profile)"
  fi
  
  echo ""
  echo "Next steps:"
  echo "  1. Switch to this vault: $(basename "$0") switch $name"
  echo "  2. Initialize structure: cust-run-config.sh init --path $path"
}

#--------------------------------------
# REMOVE VAULT
#--------------------------------------
cmd_remove() {
  local name="${1:-}"
  
  if [[ -z "$name" ]]; then
    log_error "Vault name required"
    echo "Usage: $(basename "$0") remove <name>"
    exit 1
  fi
  
  init_config
  
  # Check if exists
  local exists
  exists=$(jq -r ".vaults[\"$name\"] // empty" "$VAULTS_FILE")
  if [[ -z "$exists" ]]; then
    log_error "Vault profile '$name' not found"
    cmd_list
    exit 1
  fi
  
  # Confirm
  local path
  path=$(jq -r ".vaults[\"$name\"].path" "$VAULTS_FILE")
  
  echo "This will remove the vault profile '$name'"
  echo "Path: $path"
  echo ""
  echo "Note: This does NOT delete the actual vault files."
  read -rp "Continue? [y/N] " confirm
  
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
  fi
  
  # Remove
  local tmp_file
  tmp_file=$(mktemp)
  jq --arg name "$name" 'del(.vaults[$name])' "$VAULTS_FILE" > "$tmp_file" && mv "$tmp_file" "$VAULTS_FILE"
  
  # If this was current, clear current
  if [[ -f "$CURRENT_VAULT_FILE" ]]; then
    local current
    current=$(cat "$CURRENT_VAULT_FILE")
    if [[ "$current" == "$name" ]]; then
      rm -f "$CURRENT_VAULT_FILE"
      log_warn "Removed current vault. Run 'switch' to select another."
    fi
  fi
  
  log_success "Removed vault profile: $name"
}

#--------------------------------------
# SWITCH VAULT
#--------------------------------------
cmd_switch() {
  local name="${1:-}"
  
  if [[ -z "$name" ]]; then
    log_error "Vault name required"
    echo "Usage: $(basename "$0") switch <name>"
    echo ""
    cmd_list
    exit 1
  fi
  
  init_config
  
  # Check if exists
  local exists
  exists=$(jq -r ".vaults[\"$name\"] // empty" "$VAULTS_FILE")
  if [[ -z "$exists" ]]; then
    log_error "Vault profile '$name' not found"
    cmd_list
    exit 1
  fi
  
  # Get path
  local path
  path=$(jq -r ".vaults[\"$name\"].path" "$VAULTS_FILE")
  
  # Update current
  echo "$name" > "$CURRENT_VAULT_FILE"
  
  # Create/update symlink to config
  local vault_config="$path/.autovault/config.json"
  local main_config="$SCRIPT_DIR/../config/cust-run-config.json"
  
  if [[ -f "$vault_config" ]]; then
    # Use vault-specific config
    export CONFIG_JSON="$vault_config"
    log_success "Switched to vault: $name"
    echo "  Path: $path"
    echo "  Config: $vault_config"
  else
    # Update main config with this vault's path
    if [[ -f "$main_config" ]]; then
      local tmp_file
      tmp_file=$(mktemp)
      jq --arg path "$path" '.VaultRoot = $path' "$main_config" > "$tmp_file" && mv "$tmp_file" "$main_config"
      log_success "Switched to vault: $name"
      echo "  Path: $path"
      echo "  Updated: $main_config"
    else
      log_warn "No configuration file found"
      log_info "Run 'cust-run-config.sh config' to create one"
    fi
  fi
  
  # Update customer count
  local customer_count=0
  if [[ -d "$path/Run" ]]; then
    customer_count=$(find "$path/Run" -maxdepth 1 -type d -name "CUST-*" 2>/dev/null | wc -l) || customer_count=0
  fi
  
  local tmp_file
  tmp_file=$(mktemp)
  jq --arg name "$name" --argjson count "$customer_count" \
     '.vaults[$name].customers = $count' "$VAULTS_FILE" > "$tmp_file" && mv "$tmp_file" "$VAULTS_FILE"
}

#--------------------------------------
# CURRENT VAULT
#--------------------------------------
cmd_current() {
  init_config
  
  if [[ ! -f "$CURRENT_VAULT_FILE" ]]; then
    echo "No vault currently selected."
    echo ""
    echo "Use: $(basename "$0") switch <name>"
    cmd_list
    return 0
  fi
  
  local current
  current=$(cat "$CURRENT_VAULT_FILE")
  
  local path
  path=$(jq -r ".vaults[\"$current\"].path // \"not found\"" "$VAULTS_FILE")
  
  if [[ "$UI_AVAILABLE" == "true" ]]; then
    print_section "Current Vault"
    echo ""
    print_kv "Name" "$current"
    print_kv "Path" "$path"
    
    if [[ -d "$path" ]]; then
      local customer_count=0
      if [[ -d "$path/Run" ]]; then
        customer_count=$(find "$path/Run" -maxdepth 1 -type d -name "CUST-*" 2>/dev/null | wc -l) || customer_count=0
      fi
      print_kv "Customers" "$customer_count"
    else
      echo -e "  ${THEME[error]}Path not found${THEME[reset]}"
    fi
  else
    echo "Current vault: $current"
    echo "Path: $path"
  fi
}

#--------------------------------------
# INFO
#--------------------------------------
cmd_info() {
  local name="${1:-}"
  
  init_config
  
  # If no name, use current
  if [[ -z "$name" ]]; then
    if [[ -f "$CURRENT_VAULT_FILE" ]]; then
      name=$(cat "$CURRENT_VAULT_FILE")
    else
      log_error "No vault specified and no current vault set"
      exit 1
    fi
  fi
  
  # Check if exists
  local exists
  exists=$(jq -r ".vaults[\"$name\"] // empty" "$VAULTS_FILE")
  if [[ -z "$exists" ]]; then
    log_error "Vault profile '$name' not found"
    exit 1
  fi
  
  local path created customers
  path=$(jq -r ".vaults[\"$name\"].path" "$VAULTS_FILE")
  created=$(jq -r ".vaults[\"$name\"].created // \"unknown\"" "$VAULTS_FILE")
  customers=$(jq -r ".vaults[\"$name\"].customers // 0" "$VAULTS_FILE")
  
  if [[ "$UI_AVAILABLE" == "true" ]]; then
    print_section "Vault Info: $name"
    echo ""
    print_kv "Path" "$path"
    print_kv "Created" "$created"
    print_kv "Customers" "$customers"
    echo ""
    
    if [[ -d "$path" ]]; then
      echo -e "${THEME[success]}✓ Path exists${THEME[reset]}"
      
      # Check structure
      if [[ -d "$path/Run" ]]; then
        echo -e "${THEME[success]}✓ Run folder exists${THEME[reset]}"
      else
        echo -e "${THEME[warning]}! Run folder missing${THEME[reset]}"
      fi
      
      if [[ -d "$path/_templates" ]]; then
        echo -e "${THEME[success]}✓ Templates folder exists${THEME[reset]}"
      else
        echo -e "${THEME[warning]}! Templates folder missing${THEME[reset]}"
      fi
      
      if [[ -f "$path/.autovault/config.json" ]]; then
        echo -e "${THEME[success]}✓ Vault-specific config exists${THEME[reset]}"
      else
        echo -e "${THEME[muted]}  Using global config${THEME[reset]}"
      fi
      
      # Disk usage
      local size
      size=$(du -sh "$path" 2>/dev/null | cut -f1) || size="unknown"
      echo ""
      print_kv "Disk usage" "$size"
    else
      echo -e "${THEME[error]}✗ Path does not exist${THEME[reset]}"
    fi
  else
    echo "Vault: $name"
    echo "Path: $path"
    echo "Created: $created"
    echo "Customers: $customers"
    
    if [[ -d "$path" ]]; then
      echo "Status: OK"
    else
      echo "Status: Path not found"
    fi
  fi
}

#--------------------------------------
# MAIN
#--------------------------------------
main() {
  local cmd="${1:-}"
  shift || true
  
  case "$cmd" in
    -h|--help|help|"")
      usage
      ;;
    list|ls)
      cmd_list
      ;;
    add)
      cmd_add "$@"
      ;;
    remove|rm|delete)
      cmd_remove "$@"
      ;;
    switch|use|select)
      cmd_switch "$@"
      ;;
    current|active)
      cmd_current
      ;;
    info|show)
      cmd_info "$@"
      ;;
    *)
      log_error "Unknown command: $cmd"
      usage
      exit 1
      ;;
  esac
}

main "$@"
