#!/usr/bin/env bash
#===============================================================================
#
#  AUTOVAULT LIBRARY - hooks.sh
#
#===============================================================================
#
#  DESCRIPTION:    Hook system for AutoVault.
#                  Allows executing custom scripts before/after operations.
#
#  AVAILABLE HOOKS:
#                  pre-customer-remove   - Before removing a customer
#                  post-customer-remove  - After removing a customer
#                  post-templates-apply  - After applying templates
#                  on-error              - When any error occurs
#
#  HOOK LOCATION:  hooks/ directory in project root
#                  Or custom path via AUTOVAULT_HOOKS_DIR env var
#
#  HOOK INTERFACE:
#                  Hooks receive context as arguments:
#                  - $1: Operation name (e.g., "customer-remove")
#                  - $2: Primary argument (e.g., customer ID)
#                  - $3+: Additional context
#
#                  Environment variables available:
#                  - AUTOVAULT_HOOK: Current hook name
#                  - AUTOVAULT_OPERATION: Operation being performed
#                  - VAULT_ROOT: Path to vault
#                  - CONFIG_JSON: Path to config file
#
#  EXIT CODES:     Pre-hooks: non-zero exit cancels the operation
#                  Post-hooks: non-zero exit logs warning but continues
#                  on-error: exit code ignored
#
#  USAGE:          source "$LIB_DIR/hooks.sh"
#                  run_hook "pre-customer-remove" "42"
#
#===============================================================================

# Prevent multiple sourcing
[[ -n "${_HOOKS_SH_LOADED:-}" ]] && return 0
_HOOKS_SH_LOADED=1

#--------------------------------------
# HOOKS CONFIGURATION
#--------------------------------------
HOOKS_DIR="${AUTOVAULT_HOOKS_DIR:-}"
HOOKS_ENABLED="${AUTOVAULT_HOOKS_ENABLED:-true}"

# List of valid hooks
VALID_HOOKS=(
    "pre-customer-remove"
    "post-customer-remove"
    "post-templates-apply"
    "on-error"
)

#--------------------------------------
# FIND HOOKS DIRECTORY
#--------------------------------------
find_hooks_dir() {
    # Priority: env var > project root > config dir
    if [[ -n "$HOOKS_DIR" ]] && [[ -d "$HOOKS_DIR" ]]; then
        echo "$HOOKS_DIR"
        return 0
    fi
    
    # Try project root
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    if [[ -d "$script_dir/hooks" ]]; then
        echo "$script_dir/hooks"
        return 0
    fi
    
    # Try config directory
    if [[ -d "$script_dir/config/hooks" ]]; then
        echo "$script_dir/config/hooks"
        return 0
    fi
    
    return 1
}

#--------------------------------------
# VALIDATE HOOK NAME
#--------------------------------------
is_valid_hook() {
    local hook_name="$1"
    
    for valid in "${VALID_HOOKS[@]}"; do
        if [[ "$valid" == "$hook_name" ]]; then
            return 0
        fi
    done
    
    return 1
}

#--------------------------------------
# RUN A HOOK
#--------------------------------------
# Usage: run_hook "hook-name" [args...]
# Returns: 0 if hook succeeded or doesn't exist
#          1 if pre-hook failed (should cancel operation)
#          Hook exit code for debugging
run_hook() {
    local hook_name="$1"
    shift
    local hook_args=("$@")
    
    # Check if hooks are enabled
    if [[ "$HOOKS_ENABLED" != "true" ]]; then
        log_debug "Hooks disabled, skipping: $hook_name"
        return 0
    fi
    
    # Validate hook name
    if ! is_valid_hook "$hook_name"; then
        log_debug "Unknown hook: $hook_name"
        return 0
    fi
    
    # Find hooks directory
    local hooks_dir
    hooks_dir=$(find_hooks_dir) || {
        log_debug "No hooks directory found"
        return 0
    }
    
    # Look for hook script (supports .sh and no extension)
    local hook_script=""
    if [[ -f "$hooks_dir/$hook_name.sh" ]]; then
        hook_script="$hooks_dir/$hook_name.sh"
    elif [[ -f "$hooks_dir/$hook_name" ]]; then
        hook_script="$hooks_dir/$hook_name"
    fi
    
    # No hook found - that's OK
    if [[ -z "$hook_script" ]]; then
        log_debug "No hook script found for: $hook_name"
        return 0
    fi
    
    # Check if executable
    if [[ ! -x "$hook_script" ]]; then
        log_warn "Hook script not executable: $hook_script"
        log_warn "Run: chmod +x $hook_script"
        return 0
    fi
    
    # Prepare environment for hook
    export AUTOVAULT_HOOK="$hook_name"
    export AUTOVAULT_OPERATION="${hook_name#pre-}"
    export AUTOVAULT_OPERATION="${AUTOVAULT_OPERATION#post-}"
    
    log_debug "Running hook: $hook_name"
    log_debug "Hook script: $hook_script"
    log_debug "Hook args: ${hook_args[*]}"
    
    # Run the hook
    local hook_exit=0
    "$hook_script" "${hook_args[@]}" || hook_exit=$?
    
    # Handle exit code based on hook type
    if [[ $hook_exit -ne 0 ]]; then
        if [[ "$hook_name" == pre-* ]]; then
            # Pre-hooks failing should cancel the operation
            log_error "Pre-hook '$hook_name' failed (exit code: $hook_exit)"
            log_error "Operation cancelled by hook"
            return 1
        elif [[ "$hook_name" == "on-error" ]]; then
            # on-error hook failures are logged but ignored
            log_debug "on-error hook exited with: $hook_exit"
            return 0
        else
            # Post-hooks failing logs warning but continues
            log_warn "Post-hook '$hook_name' failed (exit code: $hook_exit)"
            return 0
        fi
    fi
    
    log_debug "Hook '$hook_name' completed successfully"
    return 0
}

#--------------------------------------
# TRIGGER ERROR HOOK
#--------------------------------------
# Call this when an error occurs
# Usage: trigger_error_hook "error message" "operation" [exit_code]
trigger_error_hook() {
    local error_message="${1:-Unknown error}"
    local operation="${2:-unknown}"
    local exit_code="${3:-1}"
    
    # Export error context
    export AUTOVAULT_ERROR_MESSAGE="$error_message"
    export AUTOVAULT_ERROR_OPERATION="$operation"
    export AUTOVAULT_ERROR_CODE="$exit_code"
    
    run_hook "on-error" "$operation" "$error_message" "$exit_code"
}

#--------------------------------------
# LIST AVAILABLE HOOKS
#--------------------------------------
list_hooks() {
    echo ""
    echo "Available AutoVault Hooks:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    for hook in "${VALID_HOOKS[@]}"; do
        local description=""
        case "$hook" in
            pre-customer-remove)
                description="Before removing a customer (can cancel)"
                ;;
            post-customer-remove)
                description="After removing a customer"
                ;;
            post-templates-apply)
                description="After applying templates"
                ;;
            on-error)
                description="When any error occurs"
                ;;
        esac
        printf "  %-25s %s\n" "$hook" "$description"
    done
    
    echo ""
    
    # Show hooks directory and installed hooks
    local hooks_dir
    hooks_dir=$(find_hooks_dir) || {
        echo "Hooks directory: not found"
        echo ""
        echo "Create a 'hooks/' directory to add custom hooks."
        return
    }
    
    echo "Hooks directory: $hooks_dir"
    echo ""
    echo "Installed hooks:"
    
    local found=false
    for hook in "${VALID_HOOKS[@]}"; do
        if [[ -f "$hooks_dir/$hook.sh" ]] || [[ -f "$hooks_dir/$hook" ]]; then
            local script="$hooks_dir/$hook.sh"
            [[ -f "$script" ]] || script="$hooks_dir/$hook"
            
            local status="✓"
            [[ -x "$script" ]] || status="⚠ (not executable)"
            
            printf "  %s %s\n" "$status" "$hook"
            found=true
        fi
    done
    
    if [[ "$found" == "false" ]]; then
        echo "  (none)"
    fi
    
    echo ""
}

#--------------------------------------
# INIT HOOKS DIRECTORY
#--------------------------------------
init_hooks_dir() {
    local target_dir="${1:-}"
    
    if [[ -z "$target_dir" ]]; then
        local script_dir
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
        target_dir="$script_dir/hooks"
    fi
    
    if [[ -d "$target_dir" ]]; then
        log_warn "Hooks directory already exists: $target_dir"
        return 0
    fi
    
    log_info "Creating hooks directory: $target_dir"
    mkdir -p "$target_dir"
    
    # Create example hooks
    create_example_hooks "$target_dir"
    
    log_success "Hooks directory initialized: $target_dir"
    echo ""
    echo "Example hooks created. Edit them to customize behavior."
    echo "Don't forget to make them executable: chmod +x hooks/*.sh"
}

#--------------------------------------
# CREATE EXAMPLE HOOKS
#--------------------------------------
create_example_hooks() {
    local hooks_dir="$1"
    
    # pre-customer-remove example
    cat > "$hooks_dir/pre-customer-remove.sh.example" << 'HOOK'
#!/usr/bin/env bash
#===============================================================================
# Hook: pre-customer-remove
# Runs BEFORE a customer is removed
# 
# Arguments:
#   $1 - Customer ID being removed
#   $2 - Customer code (e.g., CUST-042)
#
# Environment:
#   VAULT_ROOT - Path to the vault
#   CONFIG_JSON - Path to config file
#
# Exit code:
#   0 - Continue with removal
#   non-zero - Cancel the removal
#===============================================================================

CUST_ID="$1"
CUST_CODE="$2"

echo "[Hook] pre-customer-remove: $CUST_CODE"

# Example: Create backup before removal
# BACKUP_DIR="$VAULT_ROOT/../_archived_customers"
# mkdir -p "$BACKUP_DIR"
# cp -r "$VAULT_ROOT/Run/$CUST_CODE" "$BACKUP_DIR/${CUST_CODE}-$(date +%Y%m%d)"

# Example: Check if customer has active items
# if grep -rq "status: active" "$VAULT_ROOT/Run/$CUST_CODE"; then
#     echo "ERROR: Customer has active items, cannot remove"
#     exit 1
# fi

# Example: Require confirmation file
# if [[ ! -f "/tmp/confirm-remove-$CUST_ID" ]]; then
#     echo "ERROR: Create /tmp/confirm-remove-$CUST_ID to confirm"
#     exit 1
# fi

exit 0
HOOK

    # post-customer-remove example
    cat > "$hooks_dir/post-customer-remove.sh.example" << 'HOOK'
#!/usr/bin/env bash
#===============================================================================
# Hook: post-customer-remove
# Runs AFTER a customer is removed
#
# Arguments:
#   $1 - Customer ID that was removed
#   $2 - Customer code (e.g., CUST-042)
#
# Exit code: Logged but doesn't affect operation
#===============================================================================

CUST_ID="$1"
CUST_CODE="$2"

echo "[Hook] post-customer-remove: $CUST_CODE"

# Example: Send notification
# curl -X POST "$SLACK_WEBHOOK" \
#      -H "Content-Type: application/json" \
#      -d "{\"text\": \"🗑️ Customer removed: $CUST_CODE\"}"

# Example: Update external system
# curl -X DELETE "https://api.example.com/customers/$CUST_ID"

# Example: Log to audit file
# echo "$(date -Iseconds) REMOVED $CUST_CODE by $USER" >> "$VAULT_ROOT/../audit.log"

exit 0
HOOK

    # post-templates-apply example
    cat > "$hooks_dir/post-templates-apply.sh.example" << 'HOOK'
#!/usr/bin/env bash
#===============================================================================
# Hook: post-templates-apply
# Runs AFTER templates are applied to the vault
#
# Arguments:
#   $1 - Number of files updated
#
# Environment:
#   VAULT_ROOT - Path to the vault
#===============================================================================

FILES_UPDATED="${1:-0}"

echo "[Hook] post-templates-apply: $FILES_UPDATED files updated"

# Example: Regenerate index
# echo "# Customer Index" > "$VAULT_ROOT/Run/_Index.md"
# echo "" >> "$VAULT_ROOT/Run/_Index.md"
# for dir in "$VAULT_ROOT/Run"/CUST-*/; do
#     cust=$(basename "$dir")
#     echo "- [[$cust/$cust-Index|$cust]]" >> "$VAULT_ROOT/Run/_Index.md"
# done

# Example: Notify
# echo "Templates applied to $FILES_UPDATED files" | mail -s "AutoVault Update" admin@example.com

exit 0
HOOK

    # on-error example
    cat > "$hooks_dir/on-error.sh.example" << 'HOOK'
#!/usr/bin/env bash
#===============================================================================
# Hook: on-error
# Runs when ANY error occurs in AutoVault
#
# Arguments:
#   $1 - Operation that failed
#   $2 - Error message
#   $3 - Exit code
#
# Environment:
#   AUTOVAULT_ERROR_MESSAGE - Full error message
#   AUTOVAULT_ERROR_OPERATION - Operation that failed
#   AUTOVAULT_ERROR_CODE - Exit code
#===============================================================================

OPERATION="$1"
ERROR_MSG="$2"
EXIT_CODE="$3"

echo "[Hook] on-error: $OPERATION failed with code $EXIT_CODE"
echo "        Message: $ERROR_MSG"

# Example: Send alert
# curl -X POST "$ALERT_WEBHOOK" \
#      -H "Content-Type: application/json" \
#      -d "{
#        \"title\": \"AutoVault Error\",
#        \"operation\": \"$OPERATION\",
#        \"error\": \"$ERROR_MSG\",
#        \"code\": $EXIT_CODE,
#        \"host\": \"$(hostname)\",
#        \"user\": \"$USER\",
#        \"time\": \"$(date -Iseconds)\"
#      }"

# Example: Log to file
# echo "$(date -Iseconds) ERROR [$OPERATION] $ERROR_MSG (code: $EXIT_CODE)" >> /var/log/autovault-errors.log

exit 0
HOOK

    # Create README
    cat > "$hooks_dir/README.md" << 'README'
# AutoVault Hooks

This directory contains custom hooks that are executed at various points during AutoVault operations.

## Available Hooks

| Hook | When | Can Cancel |
|------|------|------------|
| `pre-customer-remove` | Before removing a customer | ✅ Yes |
| `post-customer-remove` | After removing a customer | ❌ No |
| `post-templates-apply` | After applying templates | ❌ No |
| `on-error` | When any error occurs | ❌ No |

## Creating a Hook

1. Copy the example file: `cp pre-customer-remove.sh.example pre-customer-remove.sh`
2. Make it executable: `chmod +x pre-customer-remove.sh`
3. Edit to add your logic

## Hook Interface

Hooks receive context as arguments and environment variables:

### Arguments
- `$1`, `$2`, etc. - Context specific to the hook (see examples)

### Environment Variables
- `VAULT_ROOT` - Path to the Obsidian vault
- `CONFIG_JSON` - Path to the configuration file
- `AUTOVAULT_HOOK` - Name of the current hook
- `AUTOVAULT_OPERATION` - Operation being performed

## Exit Codes

- **Pre-hooks**: Return non-zero to cancel the operation
- **Post-hooks**: Return value is logged but doesn't affect operation
- **on-error**: Return value is ignored

## Disabling Hooks

Set environment variable: `AUTOVAULT_HOOKS_ENABLED=false`

## Custom Hooks Directory

Set environment variable: `AUTOVAULT_HOOKS_DIR=/path/to/hooks`
README
}
