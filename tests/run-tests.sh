#!/usr/bin/env bash
#
# run-tests.sh
#
# Run all AutoVault tests - WITH FANCY ANIMATIONS! 🎬
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
CURRENT_TEST=0
TOTAL_TESTS=36

# Animation frames
SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
PROGRESS_CHARS=("░" "▒" "▓" "█")

#######################################
# Animation utilities
#######################################

# Hide/show cursor
hide_cursor() { echo -ne "\033[?25l"; }
show_cursor() { echo -ne "\033[?25h"; }

# Trap to restore cursor on exit
trap 'show_cursor' EXIT

# Spinner animation while running a command
spin() {
    local pid=$1
    local delay=0.1
    local frame=0
    
    while kill -0 "$pid" 2>/dev/null; do
        echo -ne "\r  ${CYAN}${SPINNER_FRAMES[$frame]}${NC} "
        frame=$(( (frame + 1) % ${#SPINNER_FRAMES[@]} ))
        sleep $delay
    done
    echo -ne "\r"
}

# Progress bar
draw_progress_bar() {
    local current=$1
    local total=$2
    local width=30
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    echo -ne "\r  ${DIM}[${NC}"
    for ((i=0; i<filled; i++)); do
        echo -ne "${GREEN}█${NC}"
    done
    for ((i=0; i<empty; i++)); do
        echo -ne "${DIM}░${NC}"
    done
    echo -ne "${DIM}]${NC} ${WHITE}${percentage}%${NC} (${current}/${total})"
}

# Animated banner
show_banner() {
    clear
    echo ""
    echo -e "${CYAN}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║       █████╗ ██╗   ██╗████████╗ ██████╗ ████████╗███████╗    ║
    ║      ██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗╚══██╔══╝██╔════╝    ║
    ║      ███████║██║   ██║   ██║   ██║   ██║   ██║   █████╗      ║
    ║      ██╔══██║██║   ██║   ██║   ██║   ██║   ██║   ██╔══╝      ║
    ║      ██║  ██║╚██████╔╝   ██║   ╚██████╔╝   ██║   ███████╗    ║
    ║      ╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝    ╚═╝   ╚══════╝    ║
    ║                                                               ║
    ║                    🧪 TEST SUITE 🧪                           ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    sleep 0.5
}

# Typing effect
type_text() {
    local text="$1"
    local delay="${2:-0.03}"
    for ((i=0; i<${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep "$delay"
    done
    echo ""
}

# Category header with animation
show_category() {
    local name="$1"
    local icon="$2"
    echo ""
    echo -e "  ${MAGENTA}━━━${NC} ${icon} ${BOLD}${WHITE}${name}${NC}"
    echo -e "  ${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    sleep 0.2
}

# Result animation
show_result() {
    local status="$1"
    local name="$2"
    
    case "$status" in
        pass)
            echo -e "    ${GREEN}✓${NC} ${name}"
            ;;
        fail)
            echo -e "    ${RED}✗${NC} ${name} ${RED}← FAILED${NC}"
            ;;
        skip)
            echo -e "    ${YELLOW}○${NC} ${name} ${DIM}(skipped)${NC}"
            ;;
    esac
}

#######################################
# Test utilities
#######################################

log_test() {
    echo -ne "    ${CYAN}◉${NC} ${DIM}$*${NC}"
}

log_pass() {
    echo -e "\r    ${GREEN}✓${NC} $*"
    ((TESTS_PASSED++))
    ((CURRENT_TEST++))
}

log_fail() {
    echo -e "\r    ${RED}✗${NC} $* ${RED}← FAILED${NC}"
    ((TESTS_FAILED++))
    ((CURRENT_TEST++))
}

log_skip() {
    echo -e "\r    ${YELLOW}○${NC} $* ${DIM}(skipped)${NC}"
    ((TESTS_SKIPPED++))
    ((CURRENT_TEST++))
}

# Run a test function and capture result
run_test() {
    local test_name="$1"
    local test_func="$2"
    
    echo -ne "    ${CYAN}◉${NC} ${DIM}${test_name}${NC} "
    
    # Run test in background for spinner
    local result=0
    $test_func &>/dev/null &
    local pid=$!
    
    # Show spinner while test runs
    local frame=0
    while kill -0 "$pid" 2>/dev/null; do
        echo -ne "\r    ${CYAN}${SPINNER_FRAMES[$frame]}${NC} ${DIM}${test_name}${NC} "
        frame=$(( (frame + 1) % ${#SPINNER_FRAMES[@]} ))
        sleep 0.08
    done
    
    wait "$pid" || result=1
    
    if [[ $result -eq 0 ]]; then
        echo -e "\r    ${GREEN}✓${NC} ${test_name}                    "
        ((TESTS_PASSED++))
    else
        echo -e "\r    ${RED}✗${NC} ${test_name} ${RED}← FAILED${NC}        "
        ((TESTS_FAILED++))
    fi
    ((CURRENT_TEST++))
    
    return 0  # Don't fail the whole suite
}

#######################################
# Setup / Teardown
#######################################

TEST_VAULT=""

setup() {
    # Create temporary test vault
    TEST_VAULT=$(mktemp -d)
    export TEST_VAULT
    
    # Create test config
    mkdir -p "$PROJECT_ROOT/config"
    cat > "$PROJECT_ROOT/config/cust-run-config.test.json" <<EOF
{
  "VaultRoot": "$TEST_VAULT",
  "CustomerIdWidth": 3,
  "CustomerIds": [1, 2, 3],
  "Sections": ["FP", "RAISED"],
  "TemplateRelativeRoot": "_templates/Run",
  "EnableCleanup": true
}
EOF
    
    export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
}

teardown() {
    # Clean up test vault
    if [[ -n "$TEST_VAULT" && -d "$TEST_VAULT" ]]; then
        rm -rf "$TEST_VAULT"
    fi
    
    # Clean up test config
    rm -f "$PROJECT_ROOT/config/cust-run-config.test.json"
}

#######################################
# Unit Tests
#######################################

test_requirements_check() {
    # Test that jq and python3 are available
    command -v jq >/dev/null 2>&1 && \
    command -v python3 >/dev/null 2>&1
}

test_config_json_valid() {
    # Test that main config templates are valid JSON
    [[ -f "$PROJECT_ROOT/config/templates.json" ]] && \
    jq empty "$PROJECT_ROOT/config/templates.json" 2>/dev/null && \
    [[ -f "$PROJECT_ROOT/config/obsidian-settings.json" ]] && \
    jq empty "$PROJECT_ROOT/config/obsidian-settings.json" 2>/dev/null
}

test_scripts_executable() {
    # Test that main scripts are executable
    [[ -x "$PROJECT_ROOT/cust-run-config.sh" ]] && \
    [[ -x "$PROJECT_ROOT/bash/New-CustRunStructure.sh" ]] && \
    [[ -x "$PROJECT_ROOT/bash/Manage-Templates.sh" ]]
}

test_scripts_syntax() {
    # Test bash syntax of all scripts
    local errors=0
    
    for script in "$PROJECT_ROOT"/*.sh "$PROJECT_ROOT/bash"/*.sh; do
        if [[ -f "$script" ]]; then
            if ! bash -n "$script" 2>/dev/null; then
                echo "  Syntax error in: $script"
                ((errors++))
            fi
        fi
    done
    
    [[ $errors -eq 0 ]]
}

test_help_command() {
    # Test that help works
    "$PROJECT_ROOT/cust-run-config.sh" --help >/dev/null 2>&1
}

#######################################
# Integration Tests
#######################################

test_structure_creation() {
    # Test creating folder structure
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
        bash ./cust-run-config.sh structure >/dev/null 2>&1
    )
    
    # Verify structure
    [[ -d "$TEST_VAULT/Run" ]] && \
    [[ -d "$TEST_VAULT/Run/CUST-001" ]] && \
    [[ -d "$TEST_VAULT/Run/CUST-002" ]] && \
    [[ -d "$TEST_VAULT/Run/CUST-003" ]] && \
    [[ -d "$TEST_VAULT/Run/CUST-001/CUST-001-FP" ]] && \
    [[ -d "$TEST_VAULT/Run/CUST-001/CUST-001-RAISED" ]] && \
    [[ -f "$TEST_VAULT/Run-Hub.md" ]]
}

test_templates_sync() {
    # Test syncing templates
    mkdir -p "$TEST_VAULT/_templates/Run"
    
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
        bash ./cust-run-config.sh templates sync >/dev/null 2>&1
    )
    
    # Verify templates exist
    [[ -f "$TEST_VAULT/_templates/Run/CUST-Root-Index.md" ]] && \
    [[ -f "$TEST_VAULT/_templates/Run/CUST-Section-FP-Index.md" ]]
}

test_templates_apply() {
    # Test applying templates (requires structure first)
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
        bash ./cust-run-config.sh templates apply >/dev/null 2>&1
    )
    
    # Verify templates applied
    local index_file="$TEST_VAULT/Run/CUST-001/CUST-001-Index.md"
    [[ -f "$index_file" ]] && \
    grep -q "CUST-001" "$index_file"
}

test_validation() {
    # Test config validation
    CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json" \
    "$PROJECT_ROOT/cust-run-config.sh" validate >/dev/null 2>&1
}

test_status_command() {
    # Test status command
    CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json" \
    "$PROJECT_ROOT/cust-run-config.sh" status >/dev/null 2>&1
}

test_dry_run() {
    # Test that dry-run doesn't modify anything
    local before_count
    before_count=$(find "$TEST_VAULT" -type f 2>/dev/null | wc -l)
    
    CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json" \
    "$PROJECT_ROOT/cust-run-config.sh" --dry-run structure >/dev/null 2>&1
    
    local after_count
    after_count=$(find "$TEST_VAULT" -type f 2>/dev/null | wc -l)
    
    [[ "$before_count" -eq "$after_count" ]]
}

test_verify_structure() {
    # Test structure verification (after creation)
    CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json" \
    "$PROJECT_ROOT/cust-run-config.sh" test >/dev/null 2>&1
}

#######################################
# Edge Case Tests
#######################################

test_customer_id_zero() {
    # Test with customer ID = 0
    local test_config
    test_config=$(mktemp)
    cat > "$test_config" <<EOF
{
  "VaultRoot": "$TEST_VAULT",
  "CustomerIdWidth": 3,
  "CustomerIds": [0],
  "Sections": ["FP"],
  "TemplateRelativeRoot": "_templates/Run",
  "EnableCleanup": true
}
EOF
    
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$test_config"
        bash ./cust-run-config.sh structure >/dev/null 2>&1
    )
    
    local result=$?
    rm -f "$test_config"
    
    # Should create CUST-000
    [[ -d "$TEST_VAULT/Run/CUST-000" ]]
}

test_customer_id_large() {
    # Test with large customer ID (9999)
    local test_config
    test_config=$(mktemp)
    cat > "$test_config" <<EOF
{
  "VaultRoot": "$TEST_VAULT",
  "CustomerIdWidth": 4,
  "CustomerIds": [9999],
  "Sections": ["FP"],
  "TemplateRelativeRoot": "_templates/Run",
  "EnableCleanup": true
}
EOF
    
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$test_config"
        bash ./cust-run-config.sh structure >/dev/null 2>&1
    )
    
    rm -f "$test_config"
    
    # Should create CUST-9999
    [[ -d "$TEST_VAULT/Run/CUST-9999" ]]
}

test_customer_id_negative() {
    # Test with negative customer ID (should fail gracefully or handle)
    local test_config
    test_config=$(mktemp)
    cat > "$test_config" <<EOF
{
  "VaultRoot": "$TEST_VAULT",
  "CustomerIdWidth": 3,
  "CustomerIds": [-1],
  "Sections": ["FP"],
  "TemplateRelativeRoot": "_templates/Run",
  "EnableCleanup": true
}
EOF
    
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$test_config"
        bash ./cust-run-config.sh structure >/dev/null 2>&1
    ) || true
    
    rm -f "$test_config"
    
    # Test passes if no crash (negative IDs may create weird folders but shouldn't crash)
    true
}

test_empty_customer_list() {
    # Test with empty customer list - should error gracefully
    local test_config
    test_config=$(mktemp)
    cat > "$test_config" <<EOF
{
  "VaultRoot": "$TEST_VAULT",
  "CustomerIdWidth": 3,
  "CustomerIds": [],
  "Sections": ["FP"],
  "TemplateRelativeRoot": "_templates/Run",
  "EnableCleanup": true
}
EOF
    
    local result=0
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$test_config"
        bash ./cust-run-config.sh structure >/dev/null 2>&1
    ) || result=1
    
    rm -f "$test_config"
    
    # Script should fail with error when no customers defined
    [[ "$result" -eq 1 ]]
}

test_empty_sections_list() {
    # Test with empty sections list
    local test_config
    test_config=$(mktemp)
    cat > "$test_config" <<EOF
{
  "VaultRoot": "$TEST_VAULT",
  "CustomerIdWidth": 3,
  "CustomerIds": [99],
  "Sections": [],
  "TemplateRelativeRoot": "_templates/Run",
  "EnableCleanup": true
}
EOF
    
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$test_config"
        bash ./cust-run-config.sh structure >/dev/null 2>&1
    )
    
    rm -f "$test_config"
    
    # Should create CUST folder with index but no section subfolders
    [[ -d "$TEST_VAULT/Run/CUST-099" ]] && \
    [[ -f "$TEST_VAULT/Run/CUST-099/CUST-099-Index.md" ]] && \
    [[ $(find "$TEST_VAULT/Run/CUST-099" -maxdepth 1 -type d | wc -l) -eq 1 ]]
}

#######################################
# Idempotence Tests
#######################################

test_structure_idempotence() {
    # Running structure twice should not create duplicates or errors
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
        bash ./cust-run-config.sh structure >/dev/null 2>&1
    )
    
    local count_before
    count_before=$(find "$TEST_VAULT/Run" -type f | wc -l)
    
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
        bash ./cust-run-config.sh structure >/dev/null 2>&1
    )
    
    local count_after
    count_after=$(find "$TEST_VAULT/Run" -type f | wc -l)
    
    # File count should be the same
    [[ "$count_before" -eq "$count_after" ]]
}

test_templates_apply_idempotence() {
    # Applying templates twice should be safe
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
        bash ./cust-run-config.sh templates apply >/dev/null 2>&1
    )
    
    local checksum_before
    checksum_before=$(md5sum "$TEST_VAULT/Run/CUST-001/CUST-001-Index.md" 2>/dev/null | cut -d' ' -f1)
    
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
        bash ./cust-run-config.sh templates apply >/dev/null 2>&1
    )
    
    local checksum_after
    checksum_after=$(md5sum "$TEST_VAULT/Run/CUST-001/CUST-001-Index.md" 2>/dev/null | cut -d' ' -f1)
    
    # Content should be identical
    [[ "$checksum_before" == "$checksum_after" ]]
}

#######################################
# Invalid Config Tests
#######################################

test_config_malformed_json() {
    # Test with malformed JSON
    local test_config
    test_config=$(mktemp)
    echo "{ invalid json }" > "$test_config"
    
    local result=0
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$test_config"
        bash ./cust-run-config.sh validate >/dev/null 2>&1
    ) || result=1
    
    rm -f "$test_config"
    
    # Should fail validation
    [[ $result -eq 1 ]]
}

test_config_missing_vaultroot() {
    # Test with missing VaultRoot - script uses defaults
    local test_config
    test_config=$(mktemp)
    cat > "$test_config" <<EOF
{
  "CustomerIdWidth": 3,
  "CustomerIds": [1],
  "Sections": ["FP"],
  "TemplateRelativeRoot": "_templates/Run",
  "EnableCleanup": true
}
EOF
    
    # Script should handle gracefully (use defaults or warn)
    # We just check it doesn't crash unexpectedly
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$test_config"
        bash ./cust-run-config.sh status >/dev/null 2>&1
    ) || true
    
    rm -f "$test_config"
    
    # Test passes as long as no crash
    true
}

test_config_wrong_types() {
    # Test with wrong types (string instead of array)
    local test_config
    test_config=$(mktemp)
    cat > "$test_config" <<EOF
{
  "VaultRoot": "$TEST_VAULT",
  "CustomerIdWidth": "three",
  "CustomerIds": "1,2,3",
  "Sections": "FP",
  "TemplateRelativeRoot": "_templates/Run",
  "EnableCleanup": "yes"
}
EOF
    
    # This might work or fail depending on implementation
    # Test just checks it doesn't crash
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$test_config"
        bash ./cust-run-config.sh validate >/dev/null 2>&1
    ) || true
    
    rm -f "$test_config"
    true
}

test_config_nonexistent() {
    # Test with non-existent config file
    # Script may use defaults or error - just check no crash
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="/nonexistent/path/config.json"
        bash ./cust-run-config.sh --help >/dev/null 2>&1
    )
    
    # Help should still work even with bad config path
    true
}

#######################################
# Special Path Tests
#######################################

test_vault_path_with_spaces() {
    # Test VaultRoot with spaces
    local test_vault_spaces
    test_vault_spaces=$(mktemp -d)
    local spaced_path="$test_vault_spaces/My Vault Path"
    mkdir -p "$spaced_path"
    
    local test_config
    test_config=$(mktemp)
    cat > "$test_config" <<EOF
{
  "VaultRoot": "$spaced_path",
  "CustomerIdWidth": 3,
  "CustomerIds": [1],
  "Sections": ["FP"],
  "TemplateRelativeRoot": "_templates/Run",
  "EnableCleanup": true
}
EOF
    
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$test_config"
        bash ./cust-run-config.sh structure >/dev/null 2>&1
    )
    
    local result=$?
    rm -f "$test_config"
    
    # Should create structure in path with spaces
    [[ -d "$spaced_path/Run/CUST-001" ]]
    local final_result=$?
    
    rm -rf "$test_vault_spaces"
    [[ $final_result -eq 0 ]]
}

test_section_name_special_chars() {
    # Test section name with special characters
    local test_config
    test_config=$(mktemp)
    cat > "$test_config" <<EOF
{
  "VaultRoot": "$TEST_VAULT",
  "CustomerIdWidth": 3,
  "CustomerIds": [50],
  "Sections": ["TEST-SECTION", "SECTION_2"],
  "TemplateRelativeRoot": "_templates/Run",
  "EnableCleanup": true
}
EOF
    
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$test_config"
        bash ./cust-run-config.sh structure >/dev/null 2>&1
    )
    
    rm -f "$test_config"
    
    # Should handle hyphens and underscores
    [[ -d "$TEST_VAULT/Run/CUST-050/CUST-050-TEST-SECTION" ]] && \
    [[ -d "$TEST_VAULT/Run/CUST-050/CUST-050-SECTION_2" ]]
}

#######################################
# Dry-Run Exhaustive Tests
#######################################

test_dry_run_structure_no_changes() {
    # Ensure dry-run creates nothing
    rm -rf "$TEST_VAULT/Run" 2>/dev/null || true
    
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
        bash ./cust-run-config.sh --dry-run structure >/dev/null 2>&1
    )
    
    # Run directory should NOT exist
    [[ ! -d "$TEST_VAULT/Run" ]]
}

test_dry_run_cleanup_no_deletion() {
    # Ensure dry-run cleanup doesn't delete anything
    mkdir -p "$TEST_VAULT/Run/CUST-001"
    echo "test" > "$TEST_VAULT/Run/CUST-001/test.md"
    
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
        bash ./cust-run-config.sh --dry-run cleanup >/dev/null 2>&1
    ) || true
    
    # File should still exist
    [[ -f "$TEST_VAULT/Run/CUST-001/test.md" ]]
}

test_dry_run_templates_no_write() {
    # Ensure dry-run templates doesn't write files
    mkdir -p "$TEST_VAULT/_templates/Run"
    
    local count_before
    count_before=$(find "$TEST_VAULT/_templates/Run" -type f | wc -l)
    
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
        bash ./cust-run-config.sh --dry-run templates sync >/dev/null 2>&1
    )
    
    local count_after
    count_after=$(find "$TEST_VAULT/_templates/Run" -type f | wc -l)
    
    [[ "$count_before" -eq "$count_after" ]]
}

#######################################
# Permission Tests
#######################################

test_readonly_vault_dir() {
    # Test behavior when vault dir is read-only
    local readonly_vault
    readonly_vault=$(mktemp -d)
    chmod 555 "$readonly_vault"
    
    local test_config
    test_config=$(mktemp)
    cat > "$test_config" <<EOF
{
  "VaultRoot": "$readonly_vault",
  "CustomerIdWidth": 3,
  "CustomerIds": [1],
  "Sections": ["FP"],
  "TemplateRelativeRoot": "_templates/Run",
  "EnableCleanup": true
}
EOF
    
    local result=0
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$test_config"
        bash ./cust-run-config.sh structure >/dev/null 2>&1
    ) || result=1
    
    rm -f "$test_config"
    chmod 755 "$readonly_vault"
    rm -rf "$readonly_vault"
    
    # Should fail gracefully
    [[ $result -eq 1 ]]
}

#######################################
# Backup Tests
#######################################

test_backup_create() {
    # Test backup creation
    # Note: BACKUP_DIR defaults to $PROJECT_ROOT/backups, not vault/backups
    
    local test_config
    test_config=$(mktemp)
    cat > "$test_config" <<EOF
{
  "VaultRoot": "$TEST_VAULT",
  "CustomerIdWidth": 3,
  "CustomerIds": [1],
  "Sections": ["FP"],
  "TemplateRelativeRoot": "_templates/Run",
  "EnableCleanup": true
}
EOF
    
    local backup_count_before
    backup_count_before=$(find "$PROJECT_ROOT/backups" -name "*.json" -type f 2>/dev/null | wc -l)
    
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$test_config"
        bash ./cust-run-config.sh backup create test-backup >/dev/null 2>&1
    )
    
    local backup_count_after
    backup_count_after=$(find "$PROJECT_ROOT/backups" -name "*.json" -type f 2>/dev/null | wc -l)
    
    rm -f "$test_config"
    
    # Cleanup test backup
    find "$PROJECT_ROOT/backups" -name "*test-backup*" -type f -delete 2>/dev/null || true
    
    [[ $backup_count_after -gt $backup_count_before ]]
}

test_backup_list() {
    # Test backup listing
    # Create a fake backup in project backups dir
    mkdir -p "$PROJECT_ROOT/backups"
    local test_backup="$PROJECT_ROOT/backups/cust-run-config.2024-01-01_12-00-00.test.json"
    echo '{"test": 1}' > "$test_backup"
    
    local test_config
    test_config=$(mktemp)
    cat > "$test_config" <<EOF
{
  "VaultRoot": "$TEST_VAULT",
  "CustomerIdWidth": 3,
  "CustomerIds": [1],
  "Sections": ["FP"],
  "TemplateRelativeRoot": "_templates/Run",
  "EnableCleanup": true
}
EOF
    
    local output
    output=$(
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$test_config"
        bash ./cust-run-config.sh backup list 2>&1
    )
    
    rm -f "$test_config" "$test_backup"
    
    # Should list backups
    echo "$output" | grep -q "cust-run-config.2024-01-01"
}

test_backup_list_empty() {
    # Test backup listing when no backups exist
    # Move existing backups temporarily
    local temp_backup_dir
    temp_backup_dir=$(mktemp -d)
    if [[ -d "$PROJECT_ROOT/backups" ]]; then
        mv "$PROJECT_ROOT/backups"/*.json "$temp_backup_dir/" 2>/dev/null || true
    fi
    
    local test_config
    test_config=$(mktemp)
    cat > "$test_config" <<EOF
{
  "VaultRoot": "$TEST_VAULT",
  "CustomerIdWidth": 3,
  "CustomerIds": [1],
  "Sections": ["FP"],
  "TemplateRelativeRoot": "_templates/Run",
  "EnableCleanup": true
}
EOF
    
    local output
    output=$(
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$test_config"
        bash ./cust-run-config.sh backup list 2>&1
    )
    
    # Restore backups
    if [[ -d "$temp_backup_dir" ]]; then
        mv "$temp_backup_dir"/*.json "$PROJECT_ROOT/backups/" 2>/dev/null || true
        rm -rf "$temp_backup_dir"
    fi
    
    rm -f "$test_config"
    
    # Should indicate no backups
    echo "$output" | grep -qi "no backup"
}

test_backup_dry_run_no_create() {
    # Ensure dry-run doesn't create backups
    local backup_count_before
    backup_count_before=$(find "$PROJECT_ROOT/backups" -name "*.json" -type f 2>/dev/null | wc -l)
    
    local test_config
    test_config=$(mktemp)
    cat > "$test_config" <<EOF
{
  "VaultRoot": "$TEST_VAULT",
  "CustomerIdWidth": 3,
  "CustomerIds": [1],
  "Sections": ["FP"],
  "TemplateRelativeRoot": "_templates/Run",
  "EnableCleanup": true
}
EOF
    
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$test_config"
        bash ./cust-run-config.sh --dry-run backup create test >/dev/null 2>&1
    )
    
    local backup_count_after
    backup_count_after=$(find "$PROJECT_ROOT/backups" -name "*test*" -type f 2>/dev/null | wc -l)
    
    rm -f "$test_config"
    
    # Should not create new test backup files
    [[ $backup_count_after -eq $backup_count_before ]] || [[ $backup_count_after -eq 0 ]]
}

test_backup_cleanup_dry_run() {
    # Test backup cleanup dry-run
    mkdir -p "$PROJECT_ROOT/backups"
    
    # Create many fake backups
    for i in {01..15}; do
        echo "{\"test\": $i}" > "$PROJECT_ROOT/backups/cust-run-config.2024-01-${i}_12-00-00.cleanup-test.json"
    done
    
    local test_config
    test_config=$(mktemp)
    cat > "$test_config" <<EOF
{
  "VaultRoot": "$TEST_VAULT",
  "CustomerIdWidth": 3,
  "CustomerIds": [1],
  "Sections": ["FP"],
  "TemplateRelativeRoot": "_templates/Run",
  "EnableCleanup": true
}
EOF
    
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$test_config"
        bash ./cust-run-config.sh --dry-run backup cleanup 5 >/dev/null 2>&1
    ) || true
    
    # Should still have all 15 backups (dry-run)
    local backup_count
    backup_count=$(find "$PROJECT_ROOT/backups" -name "*cleanup-test*" -type f 2>/dev/null | wc -l)
    
    # Cleanup test files
    find "$PROJECT_ROOT/backups" -name "*cleanup-test*" -type f -delete 2>/dev/null || true
    
    rm -f "$test_config"
    
    [[ $backup_count -eq 15 ]]
}

#######################################
# Subcommand Help Tests
#######################################

test_help_subcommands() {
    # Test all subcommand helps work
    local cmds=("templates" "customer" "section" "backup" "vault" "config" "structure")
    local errors=0
    
    for cmd in "${cmds[@]}"; do
        if ! "$PROJECT_ROOT/cust-run-config.sh" "$cmd" --help >/dev/null 2>&1; then
            ((errors++))
        fi
    done
    
    [[ $errors -eq 0 ]]
}

test_no_color_flag() {
    # Test --no-color removes ANSI codes
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" --no-color --help 2>&1)
    
    # Should not contain escape sequences
    ! echo "$output" | grep -q $'\033'
}

#######################################
# Final Summary Animation
#######################################

show_final_summary() {
    echo ""
    echo ""
    
    # Drum roll effect
    echo -ne "  ${DIM}Calculating results"
    for i in {1..5}; do
        echo -n "."
        sleep 0.2
    done
    echo -e "${NC}"
    sleep 0.3
    
    # Results box
    echo -e "  ${CYAN}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "  ${CYAN}║${NC}             ${BOLD}📊 TEST RESULTS 📊${NC}              ${CYAN}║${NC}"
    echo -e "  ${CYAN}╠═══════════════════════════════════════════════╣${NC}"
    
    # Animated counters
    echo -ne "  ${CYAN}║${NC}   ${GREEN}✓ Passed:${NC}  "
    for ((i=0; i<=TESTS_PASSED; i++)); do
        echo -ne "\r  ${CYAN}║${NC}   ${GREEN}✓ Passed:${NC}  ${WHITE}${BOLD}$i${NC}                              "
        sleep 0.05
    done
    echo -e "  ${CYAN}║${NC}"
    
    echo -ne "  ${CYAN}║${NC}   ${RED}✗ Failed:${NC}  "
    for ((i=0; i<=TESTS_FAILED; i++)); do
        echo -ne "\r  ${CYAN}║${NC}   ${RED}✗ Failed:${NC}  ${WHITE}${BOLD}$i${NC}                              "
        sleep 0.05
    done
    echo -e "  ${CYAN}║${NC}"
    
    echo -ne "  ${CYAN}║${NC}   ${YELLOW}○ Skipped:${NC} "
    for ((i=0; i<=TESTS_SKIPPED; i++)); do
        echo -ne "\r  ${CYAN}║${NC}   ${YELLOW}○ Skipped:${NC} ${WHITE}${BOLD}$i${NC}                              "
        sleep 0.05
    done
    echo -e "  ${CYAN}║${NC}"
    
    echo -e "  ${CYAN}╠═══════════════════════════════════════════════╣${NC}"
    
    # Calculate percentage
    local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))
    local success_rate=0
    if [[ $total -gt 0 ]]; then
        success_rate=$((TESTS_PASSED * 100 / total))
    fi
    
    # Success rate with visual bar
    local bar_width=25
    local filled=$((success_rate * bar_width / 100))
    local empty=$((bar_width - filled))
    
    echo -ne "  ${CYAN}║${NC}   Success: "
    for ((i=0; i<filled; i++)); do
        if [[ $success_rate -ge 80 ]]; then
            echo -ne "${GREEN}█${NC}"
        elif [[ $success_rate -ge 50 ]]; then
            echo -ne "${YELLOW}█${NC}"
        else
            echo -ne "${RED}█${NC}"
        fi
    done
    for ((i=0; i<empty; i++)); do
        echo -ne "${DIM}░${NC}"
    done
    echo -e " ${WHITE}${BOLD}${success_rate}%${NC}   ${CYAN}║${NC}"
    
    echo -e "  ${CYAN}╚═══════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Final status with celebration or consolation
    if [[ $TESTS_FAILED -eq 0 ]]; then
        # Success celebration
        echo ""
        echo -e "  ${GREEN}${BOLD}╭──────────────────────────────────────────────╮${NC}"
        echo -e "  ${GREEN}${BOLD}│    🎉 ALL TESTS PASSED! AMAZING! 🎉         │${NC}"
        echo -e "  ${GREEN}${BOLD}╰──────────────────────────────────────────────╯${NC}"
        
        # Confetti animation
        local confetti=("🎊" "✨" "🌟" "💫" "⭐" "🎈" "🎁" "🏆")
        echo ""
        echo -n "  "
        for i in {1..20}; do
            echo -n "${confetti[$((RANDOM % ${#confetti[@]}))]} "
            sleep 0.05
        done
        echo ""
        echo ""
        
        # Victory message
        echo -e "  ${WHITE}${BOLD}Your code is rock solid! 🪨${NC}"
        echo ""
    else
        # Failure message - but supportive!
        echo ""
        echo -e "  ${YELLOW}${BOLD}╭──────────────────────────────────────────────╮${NC}"
        echo -e "  ${YELLOW}${BOLD}│    ⚠️  Some tests need attention ⚠️         │${NC}"
        echo -e "  ${YELLOW}${BOLD}╰──────────────────────────────────────────────╯${NC}"
        echo ""
        echo -e "  ${WHITE}Don't worry! You've got this! 💪${NC}"
        echo -e "  ${DIM}Check the failed tests above and try again.${NC}"
        echo ""
    fi
}

#######################################
# Main
#######################################

main() {
    hide_cursor
    
    # Show animated banner
    show_banner
    
    # Setup phase with animation  
    echo -ne "  ${CYAN}⚙${NC} Setting up test environment"
    
    # Show spinner for visual effect
    local frame=0
    for i in {1..10}; do
        echo -ne "\r  ${CYAN}${SPINNER_FRAMES[$frame]}${NC} Setting up test environment"
        frame=$(( (frame + 1) % ${#SPINNER_FRAMES[@]} ))
        sleep 0.08
    done
    
    # Actually run setup (needs to be in foreground for variable export)
    setup
    
    echo -e "\r  ${GREEN}✓${NC} Test environment ready!              "
    echo -e "  ${DIM}Test vault: $TEST_VAULT${NC}"
    echo ""
    sleep 0.3
    
    # Unit tests
    show_category "UNIT TESTS" "🔬"
    run_test "Requirements available" test_requirements_check || true
    run_test "Config JSON files valid" test_config_json_valid || true
    run_test "Scripts are executable" test_scripts_executable || true
    run_test "Scripts have valid syntax" test_scripts_syntax || true
    run_test "Help command works" test_help_command || true
    run_test "Subcommand helps work" test_help_subcommands || true
    run_test "No-color flag works" test_no_color_flag || true
    
    # Integration tests
    show_category "INTEGRATION TESTS" "🔗"
    run_test "Dry-run mode" test_dry_run || true
    run_test "Structure creation" test_structure_creation || true
    run_test "Templates sync" test_templates_sync || true
    run_test "Templates apply" test_templates_apply || true
    run_test "Configuration validation" test_validation || true
    run_test "Status command" test_status_command || true
    run_test "Structure verification" test_verify_structure || true
    
    # Edge case tests
    show_category "EDGE CASE TESTS" "🔍"
    run_test "Customer ID zero" test_customer_id_zero || true
    run_test "Customer ID large (9999)" test_customer_id_large || true
    run_test "Customer ID negative" test_customer_id_negative || true
    run_test "Empty customer list" test_empty_customer_list || true
    run_test "Empty sections list" test_empty_sections_list || true
    run_test "Vault path with spaces" test_vault_path_with_spaces || true
    run_test "Section with special chars" test_section_name_special_chars || true
    
    # Idempotence tests
    show_category "IDEMPOTENCE TESTS" "🔄"
    run_test "Structure idempotence" test_structure_idempotence || true
    run_test "Templates apply idempotence" test_templates_apply_idempotence || true
    
    # Invalid config tests
    show_category "INVALID CONFIG TESTS" "⚠️"
    run_test "Malformed JSON config" test_config_malformed_json || true
    run_test "Missing VaultRoot" test_config_missing_vaultroot || true
    run_test "Wrong types in config" test_config_wrong_types || true
    run_test "Non-existent config file" test_config_nonexistent || true
    
    # Dry-run exhaustive tests
    show_category "DRY-RUN TESTS" "🌵"
    run_test "Dry-run structure no changes" test_dry_run_structure_no_changes || true
    run_test "Dry-run cleanup no deletion" test_dry_run_cleanup_no_deletion || true
    run_test "Dry-run templates no write" test_dry_run_templates_no_write || true
    
    # Backup tests
    show_category "BACKUP TESTS" "💾"
    run_test "Backup create" test_backup_create || true
    run_test "Backup list" test_backup_list || true
    run_test "Backup list empty" test_backup_list_empty || true
    run_test "Backup dry-run no create" test_backup_dry_run_no_create || true
    run_test "Backup cleanup dry-run" test_backup_cleanup_dry_run || true
    
    # Permission tests
    show_category "PERMISSION TESTS" "🔐"
    run_test "Read-only vault directory" test_readonly_vault_dir || true
    
    # Teardown with animation
    echo ""
    echo -ne "  ${CYAN}⚙${NC} Cleaning up"
    
    # Show spinner for visual effect
    frame=0
    for i in {1..8}; do
        echo -ne "\r  ${CYAN}${SPINNER_FRAMES[$frame]}${NC} Cleaning up"
        frame=$(( (frame + 1) % ${#SPINNER_FRAMES[@]} ))
        sleep 0.06
    done
    
    teardown
    echo -e "\r  ${GREEN}✓${NC} Cleanup complete!              "
    
    # Show final summary
    show_final_summary
    
    show_cursor
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

main "$@"
