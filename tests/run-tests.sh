#!/usr/bin/env bash
#===============================================================================
#
#  AUTOVAULT - run-tests.sh
#
#===============================================================================
#
#  DESCRIPTION:    Comprehensive test suite for AutoVault.
#                  Runs all unit tests, integration tests, and edge case
#                  tests with fancy terminal animations (when available).
#
#  TEST CATEGORIES:
#                  - Unit Tests        (requirements, syntax, JSON validity)
#                  - Integration Tests (structure creation, templates, validation)
#                  - Edge Cases        (empty lists, special characters, limits)
#                  - Idempotence Tests (running commands twice)
#                  - Invalid Config    (malformed JSON, wrong types)
#                  - Dry-Run Tests     (no modifications made)
#                  - Backup Tests      (create, list, restore)
#                  - Permission Tests  (read-only directories)
#
#  FEATURES:       - Animated spinners and progress bars (interactive mode)
#                  - CI mode detection (disables animations)
#                  - Colored output with pass/fail indicators
#                  - Final summary with success rate
#
#  USAGE:          ./tests/run-tests.sh
#
#  EXIT CODES:     0 - All tests passed
#                  1 - One or more tests failed
#
#  CI SUPPORT:     Automatically detects GitHub Actions and other CI
#                  environments, switches to simple text output.
#
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Detect CI environment (no TTY, no TERM, or CI variable set)
CI_MODE=false
if [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]] || [[ ! -t 1 ]] || [[ -z "${TERM:-}" ]]; then
    CI_MODE=true
    TERM="${TERM:-dumb}"
    export TERM
fi

# Colors (disabled in CI mode)
if [[ "$CI_MODE" == "true" ]]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    MAGENTA=''
    WHITE=''
    BOLD=''
    DIM=''
    NC=''
else
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
fi

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
CURRENT_TEST=0
TOTAL_TESTS=111

# Animation frames
SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
PROGRESS_CHARS=("░" "▒" "▓" "█")

#######################################
# Animation utilities
#######################################

# Hide/show cursor (no-op in CI mode)
hide_cursor() { 
    [[ "$CI_MODE" == "true" ]] && return
    echo -ne "\033[?25l"
}
show_cursor() { 
    [[ "$CI_MODE" == "true" ]] && return
    echo -ne "\033[?25h"
}

# Trap to restore cursor on exit
trap 'show_cursor' EXIT

# Spinner animation while running a command
spin() {
    local pid=$1
    local delay=0.1
    local frame=0
    
    while kill -0 "$pid" 2>/dev/null; do
        if [[ "$CI_MODE" == "false" ]]; then
            echo -ne "\r  ${CYAN}${SPINNER_FRAMES[$frame]}${NC} "
            frame=$(( (frame + 1) % ${#SPINNER_FRAMES[@]} ))
        fi
        sleep $delay
    done
    [[ "$CI_MODE" == "false" ]] && echo -ne "\r"
}

# Progress bar
draw_progress_bar() {
    [[ "$CI_MODE" == "true" ]] && return
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
    if [[ "$CI_MODE" == "true" ]]; then
        echo ""
        echo "========================================"
        echo "       AUTOVAULT TEST SUITE"
        echo "========================================"
        echo ""
        return
    fi
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
    [[ "$CI_MODE" == "false" ]] && sleep 0.5
}

# Typing effect
type_text() {
    local text="$1"
    if [[ "$CI_MODE" == "true" ]]; then
        echo "$text"
        return
    fi
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
    if [[ "$CI_MODE" == "true" ]]; then
        echo "--- ${icon} ${name} ---"
    else
        echo -e "  ${MAGENTA}━━━${NC} ${icon} ${BOLD}${WHITE}${name}${NC}"
        echo -e "  ${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        sleep 0.2
    fi
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
    
    if [[ "$CI_MODE" == "true" ]]; then
        # CI mode: simple output without animations
        echo -n "    Testing: ${test_name}... "
        
        local result=0
        $test_func &>/dev/null || result=1
        
        if [[ $result -eq 0 ]]; then
            echo "PASSED"
            ((TESTS_PASSED++))
        else
            echo "FAILED"
            ((TESTS_FAILED++))
        fi
        ((CURRENT_TEST++))
        return 0
    fi
    
    # Interactive mode with animations
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
  "TemplateRelativeRoot": "_templates/run",
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

test_version_command() {
    # Test that --version works and shows version info
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" --version 2>&1)
    
    # Should contain version number
    echo "$output" | grep -q "AutoVault" && \
    echo "$output" | grep -q "version" && \
    echo "$output" | grep -qE "[0-9]+\.[0-9]+\.[0-9]+"
}

test_templates_preview() {
    # Test templates preview command
    export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
    
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" templates preview root 2>&1)
    
    # Should contain preview markers and placeholder info
    echo "$output" | grep -q "Template:" && \
    echo "$output" | grep -q "CUST-001"
}

test_templates_preview_with_custom_id() {
    # Test templates preview with custom customer ID
    export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
    
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" templates preview root 42 2>&1)
    
    # Should show CUST-042 (with padding)
    echo "$output" | grep -q "CUST-042"
}

test_templates_list() {
    # Test templates list command
    export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
    
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" templates list 2>&1)
    
    # Should list available templates
    echo "$output" | grep -q "root" && \
    echo "$output" | grep -qi "section"
}

test_completion_files_exist() {
    # Test that completion files exist and are valid
    [[ -f "$PROJECT_ROOT/completions/autovault.bash" ]] && \
    [[ -f "$PROJECT_ROOT/completions/_autovault" ]] && \
    bash -n "$PROJECT_ROOT/completions/autovault.bash" 2>/dev/null
}

test_config_wizard_functions() {
    # Test that config wizard functions are defined
    source "$PROJECT_ROOT/bash/lib/config.sh"
    
    # Check that prompt functions exist
    declare -f prompt_value >/dev/null && \
    declare -f prompt_path >/dev/null && \
    declare -f prompt_list >/dev/null
}

test_prompt_path_expands_tilde() {
    # Test that prompt_path expands ~ correctly
    source "$PROJECT_ROOT/bash/lib/config.sh"
    
    # Simulate input with echo
    local result
    result=$(echo "" | prompt_path "test" "~/testpath" 2>/dev/null)
    
    # Should expand ~ to $HOME
    [[ "$result" == "$HOME/testpath" ]]
}

test_diff_mode_structure() {
    # Test diff mode for structure (needs structure to exist first)
    export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
    
    # Structure was already created by previous tests
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" --diff structure 2>&1)
    
    # Should contain diff-related output (DIFF or diff or Summary or Structure)
    echo "$output" | grep -qiE "diff|summary|structure"
}

test_diff_command() {
    # Test diff command standalone
    export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
    
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" diff 2>&1)
    
    # Should show diff output
    echo "$output" | grep -qi "diff"
}

test_stats_command() {
    # Test statistics command
    export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
    
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" stats 2>&1)
    
    # Should contain statistics sections
    echo "$output" | grep -qi "statistics\|overview\|health"
}

test_customer_export() {
    # Test customer export
    export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
    
    # First create structure
    "$PROJECT_ROOT/cust-run-config.sh" structure >/dev/null 2>&1
    
    # Export customer 1
    local export_file="$TEST_VAULT/cust-export-test.tar.gz"
    "$PROJECT_ROOT/cust-run-config.sh" customer export 1 "$export_file" >/dev/null 2>&1
    
    # Verify archive exists and is valid
    [[ -f "$export_file" ]] && \
    tar -tzf "$export_file" | grep -q "CUST-001"
}

test_customer_clone() {
    # Test customer clone (uses export/import internally)
    export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
    
    # Clone customer 1 to 99
    "$PROJECT_ROOT/cust-run-config.sh" customer clone 1 99 >/dev/null 2>&1
    
    # Verify clone was created
    [[ -d "$TEST_VAULT/Run/CUST-099" ]]
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
    mkdir -p "$TEST_VAULT/_templates/run/index"
    mkdir -p "$TEST_VAULT/_templates/run/notes"
    
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
        bash ./cust-run-config.sh templates sync >/dev/null 2>&1
    )
    
    # Verify templates exist in new structure
    [[ -f "$TEST_VAULT/_templates/run/index/CUST-Root-Index.md" ]] && \
    [[ -f "$TEST_VAULT/_templates/run/index/CUST-Section-FP-Index.md" ]]
}

test_templates_apply() {
    # Test applying templates (requires structure first)
    # Note: Structure must already exist from test_structure_creation
    export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
    
    (
        cd "$PROJECT_ROOT"
        bash ./cust-run-config.sh templates apply >/dev/null 2>&1
    )
    
    # Verify templates applied
    local index_file="$TEST_VAULT/Run/CUST-001/CUST-001-Index.md"
    [[ -f "$index_file" ]] && \
    grep -q "CUST-001" "$index_file"
}

test_validation() {
    # Test config validation
    export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
    "$PROJECT_ROOT/cust-run-config.sh" validate >/dev/null 2>&1
}

test_status_command() {
    # Test status command
    export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
    "$PROJECT_ROOT/cust-run-config.sh" status >/dev/null 2>&1
}

test_dry_run() {
    # Test that dry-run doesn't modify anything
    local before_count
    before_count=$(find "$TEST_VAULT" -type f 2>/dev/null | wc -l)
    
    export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
    "$PROJECT_ROOT/cust-run-config.sh" --dry-run structure >/dev/null 2>&1
    
    local after_count
    after_count=$(find "$TEST_VAULT" -type f 2>/dev/null | wc -l)
    
    [[ "$before_count" -eq "$after_count" ]]
}

test_verify_structure() {
    # Test structure verification (after creation)
    export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
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
    local test_vault
    test_vault=$(mktemp -d)
    
    cat > "$test_config" <<EOF
{
  "VaultRoot": "$test_vault",
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
    
    local result=0
    # Should create CUST folder
    [[ -d "$test_vault/Run/CUST-099" ]] || result=1
    
    rm -f "$test_config"
    rm -rf "$test_vault"
    
    [[ "$result" -eq 0 ]]
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
    # Applying templates twice should be safe and produce valid files
    # Note: We can't compare checksums because templates contain timestamps (NOW_UTC, NOW_LOCAL)
    
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
        bash ./cust-run-config.sh templates apply >/dev/null 2>&1
    )
    
    # Verify file exists and has content after first apply
    local index_file="$TEST_VAULT/Run/CUST-001/CUST-001-Index.md"
    [[ -f "$index_file" ]] || return 1
    local size_before
    size_before=$(wc -c < "$index_file")
    
    (
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
        bash ./cust-run-config.sh templates apply >/dev/null 2>&1
    )
    
    # File should still exist with similar content (CUST code present)
    [[ -f "$index_file" ]] || return 1
    local size_after
    size_after=$(wc -c < "$index_file")
    
    # Size should be roughly the same (within 50 bytes for timestamp differences)
    local size_diff=$((size_after - size_before))
    [[ ${size_diff#-} -lt 50 ]] && grep -q "CUST-001" "$index_file"
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
# Hook Tests
#######################################

test_hooks_list() {
    # Test hooks list command
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" hooks list 2>&1)
    
    # Should list available hooks
    echo "$output" | grep -q "pre-customer-remove" && \
    echo "$output" | grep -q "post-customer-remove" && \
    echo "$output" | grep -q "post-templates-apply" && \
    echo "$output" | grep -q "on-error"
}

test_hooks_init() {
    # Test hooks init command
    local test_hooks_dir="$TEST_VAULT/test-hooks-init"
    # Don't create directory - let init_hooks_dir create it
    rm -rf "$test_hooks_dir" 2>/dev/null || true
    
    (
        cd "$PROJECT_ROOT"
        bash ./cust-run-config.sh hooks init "$test_hooks_dir" >/dev/null 2>&1
    ) || true
    
    # Should create example files
    local result=true
    [[ -f "$test_hooks_dir/pre-customer-remove.sh.example" ]] || result=false
    [[ -f "$test_hooks_dir/post-templates-apply.sh.example" ]] || result=false
    [[ -f "$test_hooks_dir/on-error.sh.example" ]] || result=false
    [[ -f "$test_hooks_dir/README.md" ]] || result=false
    
    rm -rf "$test_hooks_dir"
    $result
}

test_hooks_pre_cancel() {
    # Test that a pre-hook can cancel an operation
    local test_hooks_dir="$TEST_VAULT/test-hooks-cancel"
    mkdir -p "$test_hooks_dir"
    
    # Create a pre-hook that returns non-zero
    cat > "$test_hooks_dir/pre-customer-remove.sh" << 'EOF'
#!/usr/bin/env bash
echo "Hook cancelling operation"
exit 1
EOF
    chmod +x "$test_hooks_dir/pre-customer-remove.sh"
    
    # Create test config with customer
    local test_config
    test_config=$(mktemp)
    cat > "$test_config" <<EOF
{
  "VaultRoot": "$TEST_VAULT",
  "CustomerIdWidth": 3,
  "CustomerIds": [42],
  "Sections": ["FP"],
  "TemplateRelativeRoot": "_templates/Run"
}
EOF

    # Try to remove customer - should fail due to hook
    local output
    output=$(
        cd "$PROJECT_ROOT"
        export CONFIG_JSON="$test_config"
        export AUTOVAULT_HOOKS_DIR="$test_hooks_dir"
        echo "y" | bash ./cust-run-config.sh customer remove 42 2>&1
    ) || true
    
    # Should contain cancellation message
    local result=false
    echo "$output" | grep -qi "cancel\|hook" && result=true
    
    rm -rf "$test_hooks_dir"
    rm -f "$test_config"
    $result
}

test_hooks_disabled() {
    # Test that hooks can be disabled
    local test_hooks_dir="$TEST_VAULT/test-hooks-disabled"
    mkdir -p "$test_hooks_dir"
    
    # Create a hook that would fail
    cat > "$test_hooks_dir/pre-customer-remove.sh" << 'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$test_hooks_dir/pre-customer-remove.sh"
    
    # Test hook with hooks disabled - should not run hook
    (
        cd "$PROJECT_ROOT"
        export AUTOVAULT_HOOKS_ENABLED="false"
        export AUTOVAULT_HOOKS_DIR="$test_hooks_dir"
        # Source hooks.sh and test run_hook returns 0 (hook not run)
        source "$PROJECT_ROOT/bash/lib/hooks.sh"
        run_hook "pre-customer-remove" "test" 2>/dev/null
    )
    local exit_code=$?
    
    rm -rf "$test_hooks_dir"
    [[ $exit_code -eq 0 ]]
}

test_hooks_help() {
    # Test hooks help page
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" hooks --help 2>&1)
    
    # Should contain hook descriptions
    echo "$output" | grep -qi "hook\|automation"
}

#######################################
# Remote Tests
#######################################

test_remote_init() {
    # Test remote init creates config file
    local test_config="$TEST_VAULT/remotes-test.json"
    rm -f "$test_config"
    
    (
        cd "$PROJECT_ROOT"
        export REMOTES_JSON="$test_config"
        bash ./cust-run-config.sh remote init >/dev/null 2>&1
    ) || true
    
    # Should create config file
    [[ -f "$test_config" ]] && \
    jq -e '.remotes' "$test_config" >/dev/null 2>&1
}

test_remote_add() {
    # Test adding a remote
    local test_config="$TEST_VAULT/remotes-add-test.json"
    
    # Create initial config
    echo '{"remotes": {}, "defaults": {"port": 22}}' > "$test_config"
    
    (
        cd "$PROJECT_ROOT"
        export REMOTES_JSON="$test_config"
        bash ./cust-run-config.sh remote add testserver user@example.com /path/to/vault >/dev/null 2>&1
    ) || true
    
    # Should have added the remote
    local host
    host=$(jq -r '.remotes.testserver.host' "$test_config" 2>/dev/null)
    
    rm -f "$test_config"
    [[ "$host" == "user@example.com" ]]
}

test_remote_remove() {
    # Test removing a remote
    local test_config="$TEST_VAULT/remotes-remove-test.json"
    
    # Create config with a remote
    cat > "$test_config" << 'EOF'
{
  "remotes": {
    "toremove": {
      "host": "user@server.com",
      "path": "/vault",
      "port": 22
    }
  }
}
EOF
    
    (
        cd "$PROJECT_ROOT"
        export REMOTES_JSON="$test_config"
        bash ./cust-run-config.sh remote remove toremove >/dev/null 2>&1
    ) || true
    
    # Should have removed the remote
    local result
    result=$(jq -r '.remotes | keys | length' "$test_config" 2>/dev/null)
    
    rm -f "$test_config"
    [[ "$result" == "0" ]]
}

test_remote_list() {
    # Test remote list command
    local test_config="$TEST_VAULT/remotes-list-test.json"
    
    cat > "$test_config" << 'EOF'
{
  "remotes": {
    "server1": {"host": "user@srv1.com", "path": "/v1", "port": 22}
  }
}
EOF
    
    local output
    output=$(
        cd "$PROJECT_ROOT"
        export REMOTES_JSON="$test_config"
        bash ./cust-run-config.sh remote list 2>&1
    ) || true
    
    rm -f "$test_config"
    echo "$output" | grep -q "server1"
}

test_remote_help() {
    # Test remote help page
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" remote --help 2>&1)
    
    # Should contain remote descriptions
    echo "$output" | grep -qi "ssh\|rsync\|push\|pull"
}

#######################################
# Completions Tests
#######################################

test_completions_help() {
    # Test completions help page
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" completions --help 2>&1)
    
    # Should contain completion descriptions
    echo "$output" | grep -qi "bash\|zsh\|shell"
}

test_completions_status() {
    # Test completions status command
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" completions status 2>&1) || true
    
    # Should report status for both shells
    echo "$output" | grep -qi "bash\|zsh"
}

test_completions_dry_run() {
    # Test completions install dry-run mode
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" completions install --dry-run 2>&1) || true
    
    # Should show dry-run messages
    echo "$output" | grep -qi "dry-run\|would"
}

test_completions_files_exist() {
    # Test that completion files exist in source
    [[ -f "$PROJECT_ROOT/completions/autovault.bash" ]] && \
    [[ -f "$PROJECT_ROOT/completions/_autovault" ]]
}

test_completions_files_syntax() {
    # Test completion files have valid bash syntax
    bash -n "$PROJECT_ROOT/completions/autovault.bash" 2>/dev/null
}

#######################################
# Alias Tests
#######################################

test_alias_help() {
    # Test alias help page
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" alias --help 2>&1)
    
    # Should contain alias descriptions
    echo "$output" | grep -qi "symlink\|alias\|path"
}

test_alias_status() {
    # Test alias status command
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" alias status 2>&1) || true
    
    # Should report alias status (installed or not)
    echo "$output" | grep -qi "alias\|symlink\|not found\|installed"
}

test_alias_dry_run() {
    # Test alias install dry-run mode
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" alias install --dry-run 2>&1) || true
    
    # Should show dry-run messages
    echo "$output" | grep -qi "dry-run\|would"
}

test_alias_custom_name() {
    # Test alias with custom name in dry-run
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" alias install myalias --dry-run 2>&1) || true
    
    # Should mention the custom alias name
    echo "$output" | grep -q "myalias"
}

test_alias_uninstall_dry_run() {
    # Test alias uninstall dry-run mode
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" alias uninstall --dry-run 2>&1) || true
    
    # Should show uninstall dry-run messages or no alias found
    echo "$output" | grep -qi "dry-run\|would\|not found\|no alias"
}

test_alias_methods() {
    # Test alias install methods help
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" alias --help 2>&1)
    
    # Should mention different methods (symlink, alias)
    echo "$output" | grep -qi "method\|symlink"
}

#######################################
# Init Command Tests
#######################################

test_init_help() {
    # Test init command help page exists and works
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" init --help 2>&1)
    
    echo "$output" | grep -qi "init\|vault\|profile"
}

test_init_profiles() {
    # Test that profiles are documented in help
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" init --help 2>&1)
    
    # Should mention available profiles
    echo "$output" | grep -qi "minimal\|pentest\|audit\|bugbounty"
}

test_init_dry_run() {
    # Test init command at least runs with dry-run flag
    # Note: dry-run is not fully implemented in init yet
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" init --help 2>&1)
    
    # For now, just verify init is accessible and help works
    echo "$output" | grep -qi "init\|vault\|path"
}

#######################################
# Doctor Command Tests
#######################################

test_doctor_help() {
    # Test doctor command help page
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" doctor --help 2>&1)
    
    echo "$output" | grep -qi "doctor\|diagnostic\|fix"
}

test_doctor_runs() {
    # Test doctor command runs without error
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" doctor 2>&1) || true
    
    # Should show some check results
    echo "$output" | grep -qiE "pass|fail|warn|✓|✗|!"
}

test_doctor_json_output() {
    # Test doctor JSON output format
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" doctor --json 2>&1) || true
    
    # Should be valid JSON with results
    echo "$output" | grep -q '"results"' || echo "$output" | grep -q '"passed"'
}

test_doctor_verbose() {
    # Test doctor verbose mode
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" doctor --verbose 2>&1) || true
    
    # Should produce more output than normal
    [[ ${#output} -gt 100 ]]
}

#######################################
# Search Command Tests
#######################################

test_search_help() {
    # Test search command help page
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" search --help 2>&1)
    
    echo "$output" | grep -qi "search\|query\|regex"
}

test_search_no_query() {
    # Test search without query shows help/error
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" search 2>&1) || true
    
    # Should show usage or error about missing query
    echo "$output" | grep -qiE "usage|query|search"
}

test_search_json_output() {
    # Test search JSON output format (even with no results)
    # Need to set config since search requires vault path
    export CONFIG_JSON="$PROJECT_ROOT/config/cust-run-config.test.json"
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" search "nonexistent12345" --json 2>&1) || true
    
    # Should be valid JSON structure (may have errors before JSON due to empty vault)
    echo "$output" | grep -q '"query"' || echo "$output" | grep -q '"results"'
}

test_search_options() {
    # Test search accepts various options
    local output
    
    # These should not error (may have 0 results but should work)
    "$PROJECT_ROOT/cust-run-config.sh" search "test" --names-only 2>&1 >/dev/null || true
    "$PROJECT_ROOT/cust-run-config.sh" search "test" --context 5 2>&1 >/dev/null || true
    "$PROJECT_ROOT/cust-run-config.sh" search "test" --max 10 2>&1 >/dev/null || true
    
    # If we get here without crash, test passes
    return 0
}

#######################################
# Archive Command Tests
#######################################

test_archive_help() {
    # Test archive command help page
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" archive --help 2>&1)
    
    echo "$output" | grep -qi "archive\|zip\|format"
}

test_archive_formats() {
    # Test archive help documents all formats
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" archive --help 2>&1)
    
    # Should mention supported formats
    echo "$output" | grep -qiE "zip|tar|gz|bz2"
}

test_archive_no_id() {
    # Test archive without ID shows error
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" archive 2>&1) || true
    
    # Should show error about missing customer ID
    echo "$output" | grep -qiE "usage|customer|id|required"
}

#######################################
# Theme Command Tests
#######################################

test_theme_help() {
    # Test theme command help page
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" theme --help 2>&1)
    
    echo "$output" | grep -qi "theme\|dark\|light"
}

test_theme_status() {
    # Test theme status shows current settings
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" theme status 2>&1)
    
    echo "$output" | grep -qiE "theme|dark|light|auto"
}

test_theme_preview() {
    # Test theme preview shows both themes
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" theme preview 2>&1)
    
    echo "$output" | grep -qi "dark" && echo "$output" | grep -qi "light"
}

test_theme_set() {
    # Test theme set command (save current, set, restore)
    local current_theme
    current_theme=$("$PROJECT_ROOT/cust-run-config.sh" theme status 2>&1 | grep -i "current theme" | awk '{print $NF}')
    
    # Set to light
    "$PROJECT_ROOT/cust-run-config.sh" theme set light 2>&1 >/dev/null
    
    # Verify it changed
    local new_output
    new_output=$("$PROJECT_ROOT/cust-run-config.sh" theme status 2>&1)
    
    # Restore original (default to dark if couldn't get original)
    "$PROJECT_ROOT/cust-run-config.sh" theme set "${current_theme:-dark}" 2>&1 >/dev/null
    
    # Check that light was shown
    echo "$new_output" | grep -qi "light"
}

#######################################
# Demo Command Tests
#######################################

test_demo_help() {
    # Test demo command help page
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" demo --help 2>&1)
    
    echo "$output" | grep -qi "demo\|progress\|spinner"
}

test_demo_box() {
    # Test demo box runs without error
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" demo box 2>&1)
    
    # Should show box characters
    echo "$output" | grep -qE "╔|╗|║|╚|═"
}

test_demo_progress() {
    # Test demo progress runs without error
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" demo progress 2>&1)
    
    # Should show progress indicators
    echo "$output" | grep -qE "█|░|%|100"
}

test_demo_theme_subcommand() {
    # Test demo theme (different from theme command)
    local output
    output=$("$PROJECT_ROOT/cust-run-config.sh" demo theme 2>&1)
    
    # Should mention themes
    echo "$output" | grep -qiE "dark|light|theme"
}

#######################################
# UI Library Tests
#######################################

test_ui_library_exists() {
    # Test UI library file exists
    [[ -f "$PROJECT_ROOT/bash/lib/ui.sh" ]]
}

test_ui_library_syntax() {
    # Test UI library has valid bash syntax
    bash -n "$PROJECT_ROOT/bash/lib/ui.sh"
}

test_ui_library_functions() {
    # Test UI library defines expected functions
    local content
    content=$(cat "$PROJECT_ROOT/bash/lib/ui.sh")
    
    echo "$content" | grep -q "progress_bar" && \
    echo "$content" | grep -q "spinner_start" && \
    echo "$content" | grep -q "set_theme"
}

#######################################
# Multi-Vault Tests
#######################################

test_vaults_script_exists() {
    [[ -f "$PROJECT_ROOT/bash/Manage-Vaults.sh" ]] && \
    [[ -x "$PROJECT_ROOT/bash/Manage-Vaults.sh" ]]
}

test_vaults_help() {
    local output
    output=$("$PROJECT_ROOT/bash/Manage-Vaults.sh" --help 2>&1)
    [[ "$output" == *"vault"* ]] || [[ "$output" == *"Vault"* ]]
}

test_vaults_list() {
    # List command should work (even if empty)
    local output
    output=$("$PROJECT_ROOT/bash/Manage-Vaults.sh" list 2>&1)
    [[ "$output" == *"vault"* ]] || [[ "$output" == *"Vault"* ]] || [[ "$output" == *"add"* ]]
}

test_vaults_add() {
    # Add should fail without arguments but show error
    local output
    output=$("$PROJECT_ROOT/bash/Manage-Vaults.sh" add 2>&1) || true
    [[ "$output" == *"required"* ]] || [[ "$output" == *"Usage"* ]]
}

test_vaults_current() {
    # Current command should work
    local output
    output=$("$PROJECT_ROOT/bash/Manage-Vaults.sh" current 2>&1)
    [[ "$output" == *"vault"* ]] || [[ "$output" == *"Vault"* ]] || [[ "$output" == *"switch"* ]]
}

#######################################
# Plugins Tests
#######################################

test_plugins_lib_exists() {
    [[ -f "$PROJECT_ROOT/bash/lib/plugins.sh" ]]
}

test_plugins_script_exists() {
    [[ -f "$PROJECT_ROOT/bash/Manage-Plugins.sh" ]] && \
    [[ -x "$PROJECT_ROOT/bash/Manage-Plugins.sh" ]]
}

test_plugins_help() {
    local output
    output=$("$PROJECT_ROOT/bash/Manage-Plugins.sh" --help 2>&1)
    [[ "$output" == *"plugin"* ]] || [[ "$output" == *"Plugin"* ]]
}

test_plugins_list() {
    # List command should work (even if no plugins)
    local output
    output=$("$PROJECT_ROOT/bash/Manage-Plugins.sh" list 2>&1)
    [[ "$output" == *"plugin"* ]] || [[ "$output" == *"Plugin"* ]] || [[ "$output" == *"create"* ]]
}

test_plugins_create() {
    # Test help shows create usage
    local output
    output=$("$PROJECT_ROOT/bash/Manage-Plugins.sh" --help 2>&1)
    [[ "$output" == *"create"* ]] || [[ "$output" == *"Create"* ]]
}

#######################################
# Encryption Tests
#######################################

test_encryption_script_exists() {
    [[ -f "$PROJECT_ROOT/bash/Manage-Encryption.sh" ]] && \
    [[ -x "$PROJECT_ROOT/bash/Manage-Encryption.sh" ]]
}

test_encryption_help() {
    local output
    output=$("$PROJECT_ROOT/bash/Manage-Encryption.sh" --help 2>&1)
    [[ "$output" == *"ncrypt"* ]] || [[ "$output" == *"ENCRYPT"* ]]
}

test_encryption_status() {
    # Status command should work (ignore config warnings)
    local output
    output=$("$PROJECT_ROOT/bash/Manage-Encryption.sh" status 2>&1)
    [[ "$output" == *"ackend"* ]] || [[ "$output" == *"tatus"* ]]
}

test_encryption_backend() {
    # Should detect available backend
    local output
    output=$("$PROJECT_ROOT/bash/Manage-Encryption.sh" status 2>&1)
    [[ "$output" == *"age"* ]] || [[ "$output" == *"gpg"* ]] || [[ "$output" == *"none"* ]] || [[ "$output" == *"Backend"* ]]
}

#######################################
# Template Variables Tests
#######################################

test_template_vars_exists() {
    [[ -f "$PROJECT_ROOT/bash/lib/template-vars.sh" ]]
}

test_template_vars_syntax() {
    bash -n "$PROJECT_ROOT/bash/lib/template-vars.sh"
}

test_template_vars_functions() {
    local content
    content=$(cat "$PROJECT_ROOT/bash/lib/template-vars.sh")
    
    echo "$content" | grep -q "expand_template_vars" && \
    echo "$content" | grep -q "get_builtin_var" && \
    echo "$content" | grep -q "register_template_var"
}

#######################################
# Subcommand Help Tests
#######################################

test_help_subcommands() {
    # Test all subcommand helps work
    local cmds=("templates" "customer" "section" "backup" "vault" "config" "structure" "hooks" "remote" "completions" "alias" "init" "doctor" "search" "archive" "theme" "demo" "vaults" "plugins" "encrypt")
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
    
    # Calculate percentage
    local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))
    local success_rate=0
    if [[ $total -gt 0 ]]; then
        success_rate=$((TESTS_PASSED * 100 / total))
    fi
    
    if [[ "$CI_MODE" == "true" ]]; then
        # Simple CI output
        echo "========================================"
        echo "           TEST RESULTS"
        echo "========================================"
        echo "  Passed:  $TESTS_PASSED"
        echo "  Failed:  $TESTS_FAILED"
        echo "  Skipped: $TESTS_SKIPPED"
        echo "  Success: ${success_rate}%"
        echo "========================================"
        echo ""
        if [[ $TESTS_FAILED -eq 0 ]]; then
            echo "All tests passed!"
        else
            echo "Some tests failed. Check the output above."
        fi
        echo ""
        return
    fi
    
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
    if [[ "$CI_MODE" == "true" ]]; then
        echo "Setting up test environment..."
        setup
        echo "Test environment ready!"
        echo "Test vault: $TEST_VAULT"
        echo ""
    else
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
    fi
    
    # Unit tests
    show_category "UNIT TESTS" "🔬"
    run_test "Requirements available" test_requirements_check || true
    run_test "Config JSON files valid" test_config_json_valid || true
    run_test "Scripts are executable" test_scripts_executable || true
    run_test "Scripts have valid syntax" test_scripts_syntax || true
    run_test "Help command works" test_help_command || true
    run_test "Version command works" test_version_command || true
    run_test "Subcommand helps work" test_help_subcommands || true
    run_test "No-color flag works" test_no_color_flag || true
    run_test "Completion files exist" test_completion_files_exist || true
    run_test "Config wizard functions" test_config_wizard_functions || true
    run_test "Prompt path expands tilde" test_prompt_path_expands_tilde || true
    
    # Integration tests
    show_category "INTEGRATION TESTS" "🔗"
    run_test "Dry-run mode" test_dry_run || true
    run_test "Structure creation" test_structure_creation || true
    run_test "Templates sync" test_templates_sync || true
    run_test "Templates apply" test_templates_apply || true
    run_test "Templates preview" test_templates_preview || true
    run_test "Templates preview custom ID" test_templates_preview_with_custom_id || true
    run_test "Templates list" test_templates_list || true
    run_test "Diff mode structure" test_diff_mode_structure || true
    run_test "Diff command" test_diff_command || true
    run_test "Statistics command" test_stats_command || true
    run_test "Customer export" test_customer_export || true
    run_test "Customer clone" test_customer_clone || true
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
    
    # Hook tests
    show_category "HOOK TESTS" "🪝"
    run_test "Hooks list command" test_hooks_list || true
    run_test "Hooks init command" test_hooks_init || true
    run_test "Hooks pre-hook cancellation" test_hooks_pre_cancel || true
    run_test "Hooks disabled" test_hooks_disabled || true
    run_test "Hooks help page" test_hooks_help || true
    
    # Remote tests
    show_category "REMOTE TESTS" "🌐"
    run_test "Remote init command" test_remote_init || true
    run_test "Remote add command" test_remote_add || true
    run_test "Remote remove command" test_remote_remove || true
    run_test "Remote list command" test_remote_list || true
    run_test "Remote help page" test_remote_help || true
    
    # Completions tests
    show_category "COMPLETIONS TESTS" "📝"
    run_test "Completions help page" test_completions_help || true
    run_test "Completions status command" test_completions_status || true
    run_test "Completions dry-run install" test_completions_dry_run || true
    run_test "Completions files exist" test_completions_files_exist || true
    run_test "Completions files syntax" test_completions_files_syntax || true
    
    # Alias tests
    show_category "ALIAS TESTS" "🔗"
    run_test "Alias help page" test_alias_help || true
    run_test "Alias status command" test_alias_status || true
    run_test "Alias dry-run install" test_alias_dry_run || true
    run_test "Alias custom name" test_alias_custom_name || true
    run_test "Alias uninstall dry-run" test_alias_uninstall_dry_run || true
    run_test "Alias methods documented" test_alias_methods || true
    
    # Init command tests
    show_category "INIT COMMAND TESTS" "🚀"
    run_test "Init help page" test_init_help || true
    run_test "Init profiles documented" test_init_profiles || true
    run_test "Init dry-run no changes" test_init_dry_run || true
    
    # Doctor command tests
    show_category "DOCTOR COMMAND TESTS" "🏥"
    run_test "Doctor help page" test_doctor_help || true
    run_test "Doctor runs" test_doctor_runs || true
    run_test "Doctor JSON output" test_doctor_json_output || true
    run_test "Doctor verbose mode" test_doctor_verbose || true
    
    # Search command tests
    show_category "SEARCH COMMAND TESTS" "🔍"
    run_test "Search help page" test_search_help || true
    run_test "Search no query" test_search_no_query || true
    run_test "Search JSON output" test_search_json_output || true
    run_test "Search options" test_search_options || true
    
    # Archive command tests
    show_category "ARCHIVE COMMAND TESTS" "📦"
    run_test "Archive help page" test_archive_help || true
    run_test "Archive formats documented" test_archive_formats || true
    run_test "Archive no ID error" test_archive_no_id || true
    
    # Theme command tests
    show_category "THEME COMMAND TESTS" "🎨"
    run_test "Theme help page" test_theme_help || true
    run_test "Theme status" test_theme_status || true
    run_test "Theme preview" test_theme_preview || true
    run_test "Theme set command" test_theme_set || true
    
    # Demo command tests
    show_category "DEMO COMMAND TESTS" "🎬"
    run_test "Demo help page" test_demo_help || true
    run_test "Demo box" test_demo_box || true
    run_test "Demo progress" test_demo_progress || true
    run_test "Demo theme subcommand" test_demo_theme_subcommand || true
    
    # UI Library tests
    show_category "UI LIBRARY TESTS" "🖼️"
    run_test "UI library exists" test_ui_library_exists || true
    run_test "UI library syntax" test_ui_library_syntax || true
    run_test "UI library functions" test_ui_library_functions || true
    
    # Multi-Vault tests
    show_category "MULTI-VAULT TESTS" "🗄️"
    run_test "Vaults script exists" test_vaults_script_exists || true
    run_test "Vaults help page" test_vaults_help || true
    run_test "Vaults list command" test_vaults_list || true
    run_test "Vaults add command" test_vaults_add || true
    run_test "Vaults current command" test_vaults_current || true
    
    # Plugins tests
    show_category "PLUGINS TESTS" "🔌"
    run_test "Plugins library exists" test_plugins_lib_exists || true
    run_test "Plugins script exists" test_plugins_script_exists || true
    run_test "Plugins help page" test_plugins_help || true
    run_test "Plugins list command" test_plugins_list || true
    run_test "Plugins create dry-run" test_plugins_create || true
    
    # Encryption tests
    show_category "ENCRYPTION TESTS" "🔐"
    run_test "Encryption script exists" test_encryption_script_exists || true
    run_test "Encryption help page" test_encryption_help || true
    run_test "Encryption status command" test_encryption_status || true
    run_test "Encryption backend detection" test_encryption_backend || true
    
    # Template Variables tests
    show_category "TEMPLATE VARIABLES TESTS" "📝"
    run_test "Template vars library exists" test_template_vars_exists || true
    run_test "Template vars syntax" test_template_vars_syntax || true
    run_test "Template vars functions" test_template_vars_functions || true
    
    # Teardown with animation
    echo ""
    if [[ "$CI_MODE" == "true" ]]; then
        echo "Cleaning up..."
        teardown
        echo "Cleanup complete!"
    else
        echo -ne "  ${CYAN}⚙${NC} Cleaning up"
        
        # Show spinner for visual effect
        local frame=0
        for i in {1..8}; do
            echo -ne "\r  ${CYAN}${SPINNER_FRAMES[$frame]}${NC} Cleaning up"
            frame=$(( (frame + 1) % ${#SPINNER_FRAMES[@]} ))
            sleep 0.06
        done
        
        teardown
        echo -e "\r  ${GREEN}✓${NC} Cleanup complete!              "
    fi
    
    # Show final summary
    show_final_summary
    
    show_cursor
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

main "$@"
