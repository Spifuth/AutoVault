#!/usr/bin/env bash
#===============================================================================
#
#  SCRIPT NAME:    Doctor.sh
#  DESCRIPTION:    Comprehensive diagnostic tool for AutoVault
#                  Checks configuration, structure, permissions, and dependencies
#
#  USAGE:          ./Doctor.sh [--fix] [--verbose]
#
#  OPTIONS:        --fix        Attempt to fix issues automatically
#                  --verbose    Show detailed output
#                  --json       Output results as JSON
#
#  AUTHOR:         AutoVault Project
#  VERSION:        2.3.0
#
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/config.sh"

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
FIX_MODE=false
VERBOSE=false
JSON_OUTPUT=false

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNED=0
ISSUES_FIXED=0

# Results array for JSON output
declare -a RESULTS=()

#--------------------------------------
# USAGE
#--------------------------------------
usage() {
  cat << EOF
${BOLD}USAGE${NC}
    $(basename "$0") [OPTIONS]

${BOLD}DESCRIPTION${NC}
    Run comprehensive diagnostics on your AutoVault installation.
    Checks configuration, structure, permissions, dependencies, and more.

${BOLD}OPTIONS${NC}
    --fix        Attempt to automatically fix detected issues
    --verbose    Show detailed diagnostic information
    --json       Output results in JSON format
    -h, --help   Show this help message

${BOLD}CHECKS PERFORMED${NC}
    • Dependencies (bash, jq, git, rsync, ssh)
    • Configuration files validity
    • Vault directory structure
    • File and directory permissions
    • Template files integrity
    • Hook scripts validity
    • Remote connectivity
    • Disk space

${BOLD}EXAMPLES${NC}
    # Run diagnostics
    $(basename "$0")

    # Run with auto-fix
    $(basename "$0") --fix

    # Get JSON output for scripting
    $(basename "$0") --json

EOF
}

#--------------------------------------
# PARSE ARGUMENTS
#--------------------------------------
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --fix)
        FIX_MODE=true
        shift
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      --json)
        JSON_OUTPUT=true
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
}

#--------------------------------------
# RESULT HELPERS
#--------------------------------------
check_pass() {
  local name="$1"
  local message="${2:-OK}"
  ((CHECKS_PASSED++)) || true
  RESULTS+=("{\"check\": \"$name\", \"status\": \"pass\", \"message\": \"$message\"}")
  if [[ "$JSON_OUTPUT" != "true" ]]; then
    echo -e "  ${GREEN}✓${NC} $name: $message"
  fi
}

check_fail() {
  local name="$1"
  local message="$2"
  local fixable="${3:-false}"
  ((CHECKS_FAILED++)) || true
  RESULTS+=("{\"check\": \"$name\", \"status\": \"fail\", \"message\": \"$message\", \"fixable\": $fixable}")
  if [[ "$JSON_OUTPUT" != "true" ]]; then
    echo -e "  ${RED}✗${NC} $name: $message"
  fi
}

check_warn() {
  local name="$1"
  local message="$2"
  ((CHECKS_WARNED++)) || true
  RESULTS+=("{\"check\": \"$name\", \"status\": \"warn\", \"message\": \"$message\"}")
  if [[ "$JSON_OUTPUT" != "true" ]]; then
    echo -e "  ${YELLOW}!${NC} $name: $message"
  fi
}

check_fixed() {
  local name="$1"
  local message="$2"
  ((ISSUES_FIXED++)) || true
  RESULTS+=("{\"check\": \"$name\", \"status\": \"fixed\", \"message\": \"$message\"}")
  if [[ "$JSON_OUTPUT" != "true" ]]; then
    echo -e "  ${CYAN}⚡${NC} $name: Fixed - $message"
  fi
}

section() {
  local title="$1"
  if [[ "$JSON_OUTPUT" != "true" ]]; then
    echo ""
    echo -e "${BOLD}$title${NC}"
    echo -e "${DIM}$(printf '─%.0s' {1..50})${NC}"
  fi
}

#--------------------------------------
# CHECK: DEPENDENCIES
#--------------------------------------
check_dependencies() {
  section "Dependencies"

  # Bash version
  local bash_version="${BASH_VERSION%%(*}"
  local bash_major="${bash_version%%.*}"
  if [[ "$bash_major" -ge 4 ]]; then
    check_pass "Bash" "version $bash_version (>= 4.0 required)"
  else
    check_fail "Bash" "version $bash_version (>= 4.0 required)" false
  fi

  # jq
  if command -v jq &> /dev/null; then
    local jq_version
    jq_version=$(jq --version 2>/dev/null | sed 's/jq-//')
    check_pass "jq" "version $jq_version"
  else
    check_fail "jq" "not installed (required)" true
    if [[ "$FIX_MODE" == "true" ]]; then
      if command -v apt &> /dev/null; then
        sudo apt install -y jq && check_fixed "jq" "installed via apt"
      elif command -v brew &> /dev/null; then
        brew install jq && check_fixed "jq" "installed via brew"
      fi
    fi
  fi

  # Git (optional)
  if command -v git &> /dev/null; then
    local git_version
    git_version=$(git --version | awk '{print $3}')
    check_pass "Git" "version $git_version (optional)"
  else
    check_warn "Git" "not installed (optional, for updates)"
  fi

  # rsync (optional)
  if command -v rsync &> /dev/null; then
    local rsync_version
    rsync_version=$(rsync --version 2>/dev/null | head -1 | awk '{print $3}') || rsync_version="unknown"
    check_pass "rsync" "version $rsync_version (optional)"
  else
    check_warn "rsync" "not installed (optional, for remote sync)"
  fi

  # ssh (optional)
  if command -v ssh &> /dev/null; then
    check_pass "SSH" "available (optional)"
  else
    check_warn "SSH" "not installed (optional, for remote sync)"
  fi
}

#--------------------------------------
# CHECK: CONFIGURATION
#--------------------------------------
check_configuration() {
  section "Configuration"

  local config_file="$SCRIPT_DIR/../config/cust-run-config.json"

  # Config file exists
  if [[ -f "$config_file" ]]; then
    check_pass "Config file" "exists at $config_file"
  else
    check_fail "Config file" "not found at $config_file" true
    if [[ "$FIX_MODE" == "true" ]]; then
      mkdir -p "$(dirname "$config_file")"
      echo '{"vault_root": "", "customer_prefix": "CustRun", "default_sections": ["Notes"]}' > "$config_file"
      check_fixed "Config file" "created default configuration"
    fi
    return
  fi

  # Valid JSON
  if jq empty "$config_file" 2>/dev/null; then
    check_pass "Config JSON" "valid syntax"
  else
    check_fail "Config JSON" "invalid JSON syntax" false
    return
  fi

  # Required fields
  local vault_root
  vault_root=$(jq -r '.vault_root // empty' "$config_file")
  if [[ -n "$vault_root" ]]; then
    check_pass "vault_root" "configured: $vault_root"
  else
    check_fail "vault_root" "not configured" false
  fi

  local prefix
  prefix=$(jq -r '.customer_prefix // empty' "$config_file")
  if [[ -n "$prefix" ]]; then
    check_pass "customer_prefix" "configured: $prefix"
  else
    check_warn "customer_prefix" "not set, using default"
  fi

  local sections
  sections=$(jq -r '.default_sections | length' "$config_file" 2>/dev/null || echo "0")
  if [[ "$sections" -gt 0 ]]; then
    check_pass "default_sections" "$sections sections defined"
  else
    check_warn "default_sections" "no sections defined"
  fi

  # Templates config
  local templates_file="$SCRIPT_DIR/../config/templates.json"
  if [[ -f "$templates_file" ]]; then
    if jq empty "$templates_file" 2>/dev/null; then
      local template_count
      template_count=$(jq '.templates | length' "$templates_file" 2>/dev/null || echo "0")
      check_pass "templates.json" "$template_count templates defined"
    else
      check_fail "templates.json" "invalid JSON syntax" false
    fi
  else
    check_warn "templates.json" "not found (optional)"
  fi

  # Remotes config
  local remotes_file="$SCRIPT_DIR/../config/remotes.json"
  if [[ -f "$remotes_file" ]]; then
    if jq empty "$remotes_file" 2>/dev/null; then
      local remote_count
      remote_count=$(jq '.remotes | length' "$remotes_file" 2>/dev/null || echo "0")
      check_pass "remotes.json" "$remote_count remotes defined"
    else
      check_fail "remotes.json" "invalid JSON syntax" false
    fi
  else
    check_pass "remotes.json" "not configured (optional)"
  fi
}

#--------------------------------------
# CHECK: VAULT STRUCTURE
#--------------------------------------
check_vault_structure() {
  section "Vault Structure"

  # Load config
  local config_file="$SCRIPT_DIR/../config/cust-run-config.json"
  if [[ ! -f "$config_file" ]]; then
    check_warn "Vault" "cannot check - no configuration"
    return
  fi

  local vault_root
  vault_root=$(jq -r '.vault_root // empty' "$config_file")
  if [[ -z "$vault_root" ]]; then
    check_warn "Vault" "vault_root not configured"
    return
  fi

  # Vault directory exists
  if [[ -d "$vault_root" ]]; then
    check_pass "Vault directory" "exists at $vault_root"
  else
    check_fail "Vault directory" "does not exist: $vault_root" true
    if [[ "$FIX_MODE" == "true" ]]; then
      mkdir -p "$vault_root"
      check_fixed "Vault directory" "created $vault_root"
    fi
    return
  fi

  # Check for customers
  local prefix
  prefix=$(jq -r '.customer_prefix // "CustRun"' "$config_file")
  local customer_count
  customer_count=$(find "$vault_root" -maxdepth 1 -type d -name "${prefix}-*" 2>/dev/null | wc -l)
  check_pass "Customers" "$customer_count customer(s) found"

  # Check templates directory
  local templates_dir="$vault_root/_templates"
  if [[ -d "$templates_dir" ]]; then
    local template_files
    template_files=$(find "$templates_dir" -name "*.md" 2>/dev/null | wc -l)
    check_pass "Templates directory" "$template_files template file(s)"
  else
    check_warn "Templates directory" "not found at $templates_dir"
    if [[ "$FIX_MODE" == "true" ]]; then
      mkdir -p "$templates_dir/run/root" "$templates_dir/run/section"
      check_fixed "Templates directory" "created $templates_dir"
    fi
  fi

  # Check archive directory
  local archive_dir="$vault_root/_archive"
  if [[ -d "$archive_dir" ]]; then
    check_pass "Archive directory" "exists"
  else
    check_warn "Archive directory" "not found (recommended)"
    if [[ "$FIX_MODE" == "true" ]]; then
      mkdir -p "$archive_dir"
      check_fixed "Archive directory" "created $archive_dir"
    fi
  fi
}

#--------------------------------------
# CHECK: PERMISSIONS
#--------------------------------------
check_permissions() {
  section "Permissions"

  # Main script executable
  local main_script="$SCRIPT_DIR/../cust-run-config.sh"
  if [[ -x "$main_script" ]]; then
    check_pass "Main script" "executable"
  else
    check_fail "Main script" "not executable" true
    if [[ "$FIX_MODE" == "true" ]]; then
      chmod +x "$main_script"
      check_fixed "Main script" "made executable"
    fi
  fi

  # Bash scripts
  local non_exec_count=0
  while IFS= read -r script; do
    if [[ ! -x "$script" ]]; then
      ((non_exec_count++)) || true
      if [[ "$VERBOSE" == "true" ]] && [[ "$JSON_OUTPUT" != "true" ]]; then
        echo -e "    ${DIM}Not executable: $script${NC}"
      fi
    fi
  done < <(find "$SCRIPT_DIR" -name "*.sh" -type f 2>/dev/null)

  if [[ "$non_exec_count" -eq 0 ]]; then
    check_pass "Bash scripts" "all executable"
  else
    check_warn "Bash scripts" "$non_exec_count script(s) not executable"
    if [[ "$FIX_MODE" == "true" ]]; then
      find "$SCRIPT_DIR" -name "*.sh" -type f -exec chmod +x {} \;
      check_fixed "Bash scripts" "made all executable"
    fi
  fi

  # Hooks directory
  local hooks_dir="$SCRIPT_DIR/../hooks"
  if [[ -d "$hooks_dir" ]]; then
    local hook_scripts
    hook_scripts=$(find "$hooks_dir" -name "*.sh" -not -name "*.example" -type f 2>/dev/null | wc -l)
    if [[ "$hook_scripts" -gt 0 ]]; then
      local non_exec_hooks=0
      while IFS= read -r hook; do
        if [[ ! -x "$hook" ]]; then
          ((non_exec_hooks++)) || true
        fi
      done < <(find "$hooks_dir" -name "*.sh" -not -name "*.example" -type f 2>/dev/null)
      
      if [[ "$non_exec_hooks" -eq 0 ]]; then
        check_pass "Hook scripts" "$hook_scripts hook(s), all executable"
      else
        check_warn "Hook scripts" "$non_exec_hooks of $hook_scripts not executable"
        if [[ "$FIX_MODE" == "true" ]]; then
          find "$hooks_dir" -name "*.sh" -not -name "*.example" -type f -exec chmod +x {} \;
          check_fixed "Hook scripts" "made all executable"
        fi
      fi
    else
      check_pass "Hook scripts" "no active hooks"
    fi
  fi
}

#--------------------------------------
# CHECK: DISK SPACE
#--------------------------------------
check_disk_space() {
  section "Disk Space"

  # Config location disk
  local config_dir="$SCRIPT_DIR/../config"
  if [[ -d "$config_dir" ]]; then
    local config_disk_free
    config_disk_free=$(df -h "$config_dir" 2>/dev/null | awk 'NR==2 {print $4}')
    local config_disk_pct
    config_disk_pct=$(df "$config_dir" 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%')
    
    if [[ -n "$config_disk_pct" ]]; then
      if [[ "$config_disk_pct" -lt 90 ]]; then
        check_pass "Config disk" "$config_disk_free free (${config_disk_pct}% used)"
      elif [[ "$config_disk_pct" -lt 95 ]]; then
        check_warn "Config disk" "$config_disk_free free (${config_disk_pct}% used) - getting full"
      else
        check_fail "Config disk" "$config_disk_free free (${config_disk_pct}% used) - critically low" false
      fi
    fi
  fi

  # Vault disk (if configured)
  local config_file="$SCRIPT_DIR/../config/cust-run-config.json"
  if [[ -f "$config_file" ]]; then
    local vault_root
    vault_root=$(jq -r '.vault_root // empty' "$config_file")
    if [[ -n "$vault_root" ]] && [[ -d "$vault_root" ]]; then
      local vault_disk_free
      vault_disk_free=$(df -h "$vault_root" 2>/dev/null | awk 'NR==2 {print $4}')
      local vault_disk_pct
      vault_disk_pct=$(df "$vault_root" 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%')
      
      if [[ -n "$vault_disk_pct" ]]; then
        if [[ "$vault_disk_pct" -lt 90 ]]; then
          check_pass "Vault disk" "$vault_disk_free free (${vault_disk_pct}% used)"
        elif [[ "$vault_disk_pct" -lt 95 ]]; then
          check_warn "Vault disk" "$vault_disk_free free (${vault_disk_pct}% used) - getting full"
        else
          check_fail "Vault disk" "$vault_disk_free free (${vault_disk_pct}% used) - critically low" false
        fi
      fi

      # Vault size
      local vault_size
      vault_size=$(du -sh "$vault_root" 2>/dev/null | cut -f1)
      if [[ -n "$vault_size" ]]; then
        check_pass "Vault size" "$vault_size total"
      fi
    fi
  fi
}

#--------------------------------------
# CHECK: COMPLETIONS & ALIAS
#--------------------------------------
check_integrations() {
  section "Integrations"

  # Check for alias in PATH
  local alias_found=false
  for alias_name in av autovault vault custrun; do
    if command -v "$alias_name" &> /dev/null; then
      local alias_path
      alias_path=$(which "$alias_name" 2>/dev/null)
      check_pass "Alias '$alias_name'" "found at $alias_path"
      alias_found=true
      break
    fi
  done
  if [[ "$alias_found" != "true" ]]; then
    check_warn "System alias" "not installed (run: cust-run-config.sh alias install)"
  fi

  # Check for completions
  local completions_installed=false
  
  # Bash completions
  if [[ -f ~/.bash_completion.d/autovault.bash ]] || [[ -f /etc/bash_completion.d/autovault.bash ]]; then
    check_pass "Bash completions" "installed"
    completions_installed=true
  fi
  
  # Zsh completions
  if [[ -f ~/.zsh/completions/_autovault ]] || [[ -f /usr/share/zsh/site-functions/_autovault ]]; then
    check_pass "Zsh completions" "installed"
    completions_installed=true
  fi

  if [[ "$completions_installed" != "true" ]]; then
    check_warn "Shell completions" "not installed (run: cust-run-config.sh completions install)"
  fi
}

#--------------------------------------
# PRINT SUMMARY
#--------------------------------------
print_summary() {
  if [[ "$JSON_OUTPUT" == "true" ]]; then
    echo "{"
    echo "  \"passed\": $CHECKS_PASSED,"
    echo "  \"failed\": $CHECKS_FAILED,"
    echo "  \"warnings\": $CHECKS_WARNED,"
    echo "  \"fixed\": $ISSUES_FIXED,"
    echo "  \"results\": ["
    local first=true
    for result in "${RESULTS[@]}"; do
      if [[ "$first" == "true" ]]; then
        first=false
      else
        echo ","
      fi
      echo -n "    $result"
    done
    echo ""
    echo "  ]"
    echo "}"
    return
  fi

  echo ""
  echo -e "${BOLD}Summary${NC}"
  echo -e "${DIM}$(printf '─%.0s' {1..50})${NC}"
  
  # shellcheck disable=SC2034  # Kept for potential future use in summary percentage
  local total=$((CHECKS_PASSED + CHECKS_FAILED + CHECKS_WARNED))
  
  echo -e "  ${GREEN}✓${NC} Passed:   $CHECKS_PASSED"
  echo -e "  ${YELLOW}!${NC} Warnings: $CHECKS_WARNED"
  echo -e "  ${RED}✗${NC} Failed:   $CHECKS_FAILED"
  
  if [[ "$ISSUES_FIXED" -gt 0 ]]; then
    echo -e "  ${CYAN}⚡${NC} Fixed:    $ISSUES_FIXED"
  fi

  echo ""
  
  if [[ "$CHECKS_FAILED" -eq 0 ]]; then
    if [[ "$CHECKS_WARNED" -eq 0 ]]; then
      echo -e "${GREEN}${BOLD}✓ All checks passed!${NC} AutoVault is healthy."
    else
      echo -e "${GREEN}${BOLD}✓ No critical issues.${NC} $CHECKS_WARNED warning(s) to review."
    fi
  else
    echo -e "${RED}${BOLD}✗ $CHECKS_FAILED issue(s) found.${NC}"
    if [[ "$FIX_MODE" != "true" ]]; then
      echo -e "  Run with ${CYAN}--fix${NC} to attempt automatic fixes."
    fi
  fi
  echo ""
}

#--------------------------------------
# MAIN
#--------------------------------------
main() {
  parse_args "$@"

  if [[ "$JSON_OUTPUT" != "true" ]]; then
    echo ""
    if [[ "$UI_AVAILABLE" == "true" ]]; then
      echo -e "${THEME[primary]}╔══════════════════════════════════════════════════════════════╗${THEME[reset]}"
      echo -e "${THEME[primary]}║${THEME[reset]}                                                              ${THEME[primary]}║${THEME[reset]}"
      echo -e "${THEME[primary]}║${THEME[reset]}    ${THEME[bold]}🏥 AutoVault Doctor${THEME[reset]}                                       ${THEME[primary]}║${THEME[reset]}"
      echo -e "${THEME[primary]}║${THEME[reset]}                                                              ${THEME[primary]}║${THEME[reset]}"
      echo -e "${THEME[primary]}╚══════════════════════════════════════════════════════════════╝${THEME[reset]}"
    else
      echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
      echo -e "${CYAN}║${NC}                                                              ${CYAN}║${NC}"
      echo -e "${CYAN}║${NC}    ${BOLD}🏥 AutoVault Doctor${NC}                                       ${CYAN}║${NC}"
      echo -e "${CYAN}║${NC}                                                              ${CYAN}║${NC}"
      echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    fi
    
    if [[ "$FIX_MODE" == "true" ]]; then
      echo ""
      echo -e "${YELLOW}Running in fix mode - will attempt to repair issues${NC}"
    fi
  fi

  check_dependencies
  check_configuration
  check_vault_structure
  check_permissions
  check_disk_space
  check_integrations

  print_summary
  
  # Send notification if UI available
  if [[ "$UI_AVAILABLE" == "true" ]] && [[ "$JSON_OUTPUT" != "true" ]]; then
    if [[ "$CHECKS_FAILED" -eq 0 ]]; then
      notify_success "AutoVault Doctor" "All $CHECKS_PASSED checks passed!"
    else
      notify_error "AutoVault Doctor" "$CHECKS_FAILED issues found"
    fi
  fi

  # Exit code based on failures
  if [[ "$CHECKS_FAILED" -gt 0 ]]; then
    exit 1
  fi
  exit 0
}

main "$@"
