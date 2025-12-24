#!/usr/bin/env bash
#===============================================================================
#
#  AUTOVAULT - template-vars.sh (Library)
#
#===============================================================================
#
#  DESCRIPTION:    Dynamic template variable system for AutoVault.
#                  Provides built-in variables and supports custom variables.
#
#  BUILT-IN VARIABLES:
#     {{CUST_CODE}}      - Customer code (e.g., CUST-001)
#     {{CUST_NAME}}      - Customer name from config
#     {{SECTION}}        - Current section (e.g., FP, RAISED)
#     {{NOW_UTC}}        - Current UTC timestamp (ISO 8601)
#     {{NOW_LOCAL}}      - Current local timestamp
#     {{DATE}}           - Current date (YYYY-MM-DD)
#     {{TIME}}           - Current time (HH:MM:SS)
#     {{YEAR}}           - Current year (YYYY)
#     {{MONTH}}          - Current month (MM)
#     {{DAY}}            - Current day (DD)
#     {{USER}}           - Current username
#     {{HOSTNAME}}       - Machine hostname
#     {{VAULT_ROOT}}     - Path to vault root
#     {{VAULT_NAME}}     - Name of current vault
#     {{RANDOM_ID}}      - Random 8-char ID
#     {{UUID}}           - Generated UUID v4
#
#  CONDITIONAL SYNTAX:
#     {{IF:VAR}}...{{ENDIF:VAR}}     - Include content if VAR is set
#     {{IFNOT:VAR}}...{{ENDIF:VAR}}  - Include content if VAR is not set
#
#  USAGE:
#     source bash/lib/template-vars.sh
#     content=$(expand_template_vars "$content" "$cust_code" "$section")
#
#===============================================================================

# Associative array for custom variables
declare -gA TEMPLATE_CUSTOM_VARS

#--------------------------------------
# Register a custom variable
#--------------------------------------
register_template_var() {
    local name="$1"
    local value="$2"
    TEMPLATE_CUSTOM_VARS["$name"]="$value"
}

#--------------------------------------
# Clear all custom variables
# shellcheck disable=SC2034  # Public API function for external use
#--------------------------------------
clear_template_vars() {
    TEMPLATE_CUSTOM_VARS=()
}

#--------------------------------------
# Get built-in variable value
#--------------------------------------
get_builtin_var() {
    local name="$1"
    local cust_code="${2:-}"
    local section="${3:-}"
    
    case "$name" in
        CUST_CODE)
            echo "${cust_code:-}"
            ;;
        SECTION)
            echo "${section:-}"
            ;;
        NOW_UTC)
            date -u +"%Y-%m-%dT%H:%M:%SZ"
            ;;
        NOW_LOCAL)
            date +"%Y-%m-%dT%H:%M:%S%z"
            ;;
        DATE)
            date +"%Y-%m-%d"
            ;;
        TIME)
            date +"%H:%M:%S"
            ;;
        YEAR)
            date +"%Y"
            ;;
        MONTH)
            date +"%m"
            ;;
        DAY)
            date +"%d"
            ;;
        WEEK)
            date +"%V"
            ;;
        WEEKDAY)
            date +"%A"
            ;;
        WEEKDAY_SHORT)
            date +"%a"
            ;;
        USER)
            echo "${USER:-$(whoami)}"
            ;;
        HOSTNAME)
            hostname 2>/dev/null || echo "unknown"
            ;;
        VAULT_ROOT)
            echo "${VAULT_ROOT:-}"
            ;;
        VAULT_NAME)
            if [[ -n "${VAULT_ROOT:-}" ]]; then
                basename "$VAULT_ROOT"
            else
                echo ""
            fi
            ;;
        RANDOM_ID)
            # Generate random 8-char alphanumeric ID
            head -c 4 /dev/urandom | xxd -p
            ;;
        UUID)
            # Generate UUID v4
            if command -v uuidgen &>/dev/null; then
                uuidgen | tr '[:upper:]' '[:lower:]'
            else
                # Fallback: generate pseudo-UUID
                printf '%08x-%04x-4%03x-%04x-%012x' \
                    $((RANDOM * RANDOM)) \
                    $((RANDOM)) \
                    $((RANDOM % 4096)) \
                    $((RANDOM % 16384 + 32768)) \
                    $((RANDOM * RANDOM * RANDOM))
            fi
            ;;
        VERSION)
            echo "${AUTOVAULT_VERSION:-2.8.0}"
            ;;
        OS)
            uname -s
            ;;
        *)
            # Check custom variables
            if [[ -v TEMPLATE_CUSTOM_VARS["$name"] ]]; then
                echo "${TEMPLATE_CUSTOM_VARS[$name]}"
            else
                echo ""
            fi
            ;;
    esac
}

#--------------------------------------
# Expand all template variables in content
#--------------------------------------
expand_template_vars() {
    local content="$1"
    local cust_code="${2:-}"
    local section="${3:-}"
    
    # List of built-in variables to process
    local vars=(
        CUST_CODE SECTION
        NOW_UTC NOW_LOCAL DATE TIME YEAR MONTH DAY WEEK WEEKDAY WEEKDAY_SHORT
        USER HOSTNAME
        VAULT_ROOT VAULT_NAME
        RANDOM_ID UUID VERSION OS
    )
    
    # Replace built-in variables
    for var in "${vars[@]}"; do
        local value
        value=$(get_builtin_var "$var" "$cust_code" "$section")
        content="${content//\{\{$var\}\}/$value}"
    done
    
    # Replace custom variables
    for key in "${!TEMPLATE_CUSTOM_VARS[@]}"; do
        content="${content//\{\{$key\}\}/${TEMPLATE_CUSTOM_VARS[$key]}}"
    done
    
    # Process conditionals: {{IF:VAR}}...{{ENDIF:VAR}}
    content=$(process_conditionals "$content" "$cust_code" "$section")
    
    echo "$content"
}

#--------------------------------------
# Process conditional blocks
#--------------------------------------
process_conditionals() {
    local content="$1"
    local cust_code="${2:-}"
    local section="${3:-}"
    
    # Process {{IF:VAR}}...{{ENDIF:VAR}}
    while [[ "$content" =~ \{\{IF:([A-Z_]+)\}\}(.*)\{\{ENDIF:\1\}\} ]]; do
        local var_name="${BASH_REMATCH[1]}"
        local block_content="${BASH_REMATCH[2]}"
        local full_match="${BASH_REMATCH[0]}"
        
        local value
        value=$(get_builtin_var "$var_name" "$cust_code" "$section")
        
        if [[ -n "$value" ]]; then
            # Variable is set, keep the content (but not the tags)
            content="${content//$full_match/$block_content}"
        else
            # Variable is empty, remove the whole block
            content="${content//$full_match/}"
        fi
    done
    
    # Process {{IFNOT:VAR}}...{{ENDIF:VAR}}
    while [[ "$content" =~ \{\{IFNOT:([A-Z_]+)\}\}(.*)\{\{ENDIF:\1\}\} ]]; do
        local var_name="${BASH_REMATCH[1]}"
        local block_content="${BASH_REMATCH[2]}"
        local full_match="${BASH_REMATCH[0]}"
        
        local value
        value=$(get_builtin_var "$var_name" "$cust_code" "$section")
        
        if [[ -z "$value" ]]; then
            # Variable is empty, keep the content
            content="${content//$full_match/$block_content}"
        else
            # Variable is set, remove the block
            content="${content//$full_match/}"
        fi
    done
    
    echo "$content"
}

#--------------------------------------
# List available template variables
#--------------------------------------
list_template_vars() {
    cat << 'EOF'
Built-in Template Variables
============================

Date & Time:
  {{NOW_UTC}}         Current UTC timestamp (ISO 8601)
  {{NOW_LOCAL}}       Current local timestamp
  {{DATE}}            Current date (YYYY-MM-DD)
  {{TIME}}            Current time (HH:MM:SS)
  {{YEAR}}            Current year (YYYY)
  {{MONTH}}           Current month (MM)
  {{DAY}}             Current day (DD)
  {{WEEK}}            Week number (01-52)
  {{WEEKDAY}}         Full weekday name
  {{WEEKDAY_SHORT}}   Short weekday name (Mon, Tue, etc.)

Context:
  {{CUST_CODE}}       Customer code (CUST-001)
  {{SECTION}}         Section name (FP, RAISED, etc.)

Environment:
  {{USER}}            Current username
  {{HOSTNAME}}        Machine hostname
  {{VAULT_ROOT}}      Full path to vault
  {{VAULT_NAME}}      Vault folder name
  {{OS}}              Operating system

Identifiers:
  {{RANDOM_ID}}       Random 8-character hex ID
  {{UUID}}            Generated UUID v4
  {{VERSION}}         AutoVault version

Conditionals:
  {{IF:VAR}}...{{ENDIF:VAR}}       Include if VAR is set
  {{IFNOT:VAR}}...{{ENDIF:VAR}}    Include if VAR is empty

Custom Variables:
  Use register_template_var "NAME" "value" to add custom variables.
  Then use {{NAME}} in templates.

Example:
  ---
  created: {{NOW_UTC}}
  author: {{USER}}
  customer: {{CUST_CODE}}
  ---
  # {{CUST_CODE}} - {{SECTION}}
  Created on {{DATE}} by {{USER}}
  {{IF:SECTION}}Section: {{SECTION}}{{ENDIF:SECTION}}

EOF
}

#--------------------------------------
# Preview template with current values
#--------------------------------------
preview_template() {
    local template_file="$1"
    local cust_code="${2:-CUST-001}"
    local section="${3:-FP}"
    
    if [[ ! -f "$template_file" ]]; then
        echo "Error: Template file not found: $template_file" >&2
        return 1
    fi
    
    local content
    content=$(cat "$template_file")
    
    expand_template_vars "$content" "$cust_code" "$section"
}

#--------------------------------------
# Validate template syntax
#--------------------------------------
validate_template() {
    local content="$1"
    local errors=()
    
    # Check for unclosed IF blocks
    local if_count
    local endif_count
    if_count=$(grep -oE '\{\{IF:[A-Z_]+\}\}' <<< "$content" | wc -l) || if_count=0
    endif_count=$(grep -oE '\{\{ENDIF:[A-Z_]+\}\}' <<< "$content" | wc -l) || endif_count=0
    
    if [[ "$if_count" -ne "$endif_count" ]]; then
        errors+=("Mismatched IF/ENDIF blocks (IF: $if_count, ENDIF: $endif_count)")
    fi
    
    # Check for invalid variable syntax
    local invalid_vars
    invalid_vars=$(grep -oE '\{\{[^}]*[a-z][^}]*\}\}' <<< "$content" | head -5) || true
    if [[ -n "$invalid_vars" ]]; then
        errors+=("Variables should use UPPERCASE: $invalid_vars")
    fi
    
    # Check for unknown variables
    local all_vars
    all_vars=$(grep -oE '\{\{[A-Z_]+\}\}' <<< "$content") || true
    
    local known_vars="CUST_CODE|SECTION|NOW_UTC|NOW_LOCAL|DATE|TIME|YEAR|MONTH|DAY|WEEK|WEEKDAY|WEEKDAY_SHORT|USER|HOSTNAME|VAULT_ROOT|VAULT_NAME|RANDOM_ID|UUID|VERSION|OS"
    
    while IFS= read -r var; do
        [[ -z "$var" ]] && continue
        local var_name="${var//\{\{/}"
        var_name="${var_name//\}\}/}"
        
        if [[ ! "$var_name" =~ ^($known_vars)$ ]] && [[ ! -v TEMPLATE_CUSTOM_VARS["$var_name"] ]]; then
            errors+=("Unknown variable: $var")
        fi
    done <<< "$all_vars"
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        echo "Template validation errors:"
        for err in "${errors[@]}"; do
            echo "  - $err"
        done
        return 1
    fi
    
    echo "Template is valid"
    return 0
}
