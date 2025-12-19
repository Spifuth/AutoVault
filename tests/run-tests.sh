#!/usr/bin/env bash
#
# run-tests.sh
#
# Run all AutoVault tests
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

#######################################
# Test utilities
#######################################

log_test() {
    echo -e "${BLUE}[TEST]${NC} $*"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
    ((TESTS_FAILED++))
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $*"
    ((TESTS_SKIPPED++))
}

# Run a test function and capture result
run_test() {
    local test_name="$1"
    local test_func="$2"
    
    log_test "$test_name"
    
    if $test_func; then
        log_pass "$test_name"
        return 0
    else
        log_fail "$test_name"
        return 1
    fi
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
# Main
#######################################

main() {
    echo "========================================"
    echo "       AutoVault Test Suite"
    echo "========================================"
    echo ""
    
    # Setup
    echo "Setting up test environment..."
    setup
    echo "Test vault: $TEST_VAULT"
    echo ""
    
    # Unit tests
    echo "--- Unit Tests ---"
    run_test "Requirements available" test_requirements_check || true
    run_test "Config JSON files valid" test_config_json_valid || true
    run_test "Scripts are executable" test_scripts_executable || true
    run_test "Scripts have valid syntax" test_scripts_syntax || true
    run_test "Help command works" test_help_command || true
    echo ""
    
    # Integration tests
    echo "--- Integration Tests ---"
    run_test "Dry-run mode" test_dry_run || true
    run_test "Structure creation" test_structure_creation || true
    run_test "Templates sync" test_templates_sync || true
    run_test "Templates apply" test_templates_apply || true
    run_test "Configuration validation" test_validation || true
    run_test "Status command" test_status_command || true
    run_test "Structure verification" test_verify_structure || true
    echo ""
    
    # Teardown
    echo "Cleaning up..."
    teardown
    echo ""
    
    # Summary
    echo "========================================"
    echo "               Results"
    echo "========================================"
    echo -e "  ${GREEN}Passed:${NC}  $TESTS_PASSED"
    echo -e "  ${RED}Failed:${NC}  $TESTS_FAILED"
    echo -e "  ${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
    echo "========================================"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
    exit 0
}

main "$@"
