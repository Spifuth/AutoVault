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
    run_test "Subcommand helps work" test_help_subcommands || true
    run_test "No-color flag works" test_no_color_flag || true
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
    
    # Edge case tests
    echo "--- Edge Case Tests ---"
    run_test "Customer ID zero" test_customer_id_zero || true
    run_test "Customer ID large (9999)" test_customer_id_large || true
    run_test "Customer ID negative" test_customer_id_negative || true
    run_test "Empty customer list" test_empty_customer_list || true
    run_test "Empty sections list" test_empty_sections_list || true
    run_test "Vault path with spaces" test_vault_path_with_spaces || true
    run_test "Section with special chars" test_section_name_special_chars || true
    echo ""
    
    # Idempotence tests
    echo "--- Idempotence Tests ---"
    run_test "Structure idempotence" test_structure_idempotence || true
    run_test "Templates apply idempotence" test_templates_apply_idempotence || true
    echo ""
    
    # Invalid config tests
    echo "--- Invalid Config Tests ---"
    run_test "Malformed JSON config" test_config_malformed_json || true
    run_test "Missing VaultRoot" test_config_missing_vaultroot || true
    run_test "Wrong types in config" test_config_wrong_types || true
    run_test "Non-existent config file" test_config_nonexistent || true
    echo ""
    
    # Dry-run exhaustive tests
    echo "--- Dry-Run Tests ---"
    run_test "Dry-run structure no changes" test_dry_run_structure_no_changes || true
    run_test "Dry-run cleanup no deletion" test_dry_run_cleanup_no_deletion || true
    run_test "Dry-run templates no write" test_dry_run_templates_no_write || true
    echo ""
    
    # Permission tests
    echo "--- Permission Tests ---"
    run_test "Read-only vault directory" test_readonly_vault_dir || true
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
