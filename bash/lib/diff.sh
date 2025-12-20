#!/usr/bin/env bash
#===============================================================================
#
#  AUTOVAULT LIBRARY - diff.sh
#
#===============================================================================
#
#  DESCRIPTION:    Diff utilities for previewing changes before applying them.
#                  Shows what would be created, modified, or deleted.
#
#  FUNCTIONS:      diff_structure()     - Compare expected vs actual structure
#                  diff_templates()     - Compare template content
#                  show_diff_summary()  - Display diff summary
#                  colorize_diff()      - Add colors to diff output
#
#  USAGE:          source "$LIB_DIR/diff.sh"
#                  diff_structure "$vault_root"
#
#  OUTPUT:         + Added (green)
#                  - Removed (red)  
#                  ~ Modified (yellow)
#                  = Unchanged (dim)
#
#===============================================================================

# Prevent multiple sourcing
[[ -n "${_DIFF_SH_LOADED:-}" ]] && return 0
_DIFF_SH_LOADED=1

#--------------------------------------
# DIFF COLORS
#--------------------------------------
_diff_green()  { echo -e "\033[32m$*\033[0m"; }
_diff_red()    { echo -e "\033[31m$*\033[0m"; }
_diff_yellow() { echo -e "\033[33m$*\033[0m"; }
_diff_dim()    { echo -e "\033[2m$*\033[0m"; }
_diff_bold()   { echo -e "\033[1m$*\033[0m"; }
_diff_cyan()   { echo -e "\033[36m$*\033[0m"; }

#--------------------------------------
# DIFF COUNTERS
#--------------------------------------
DIFF_ADDED=0
DIFF_REMOVED=0
DIFF_MODIFIED=0
DIFF_UNCHANGED=0

reset_diff_counters() {
    DIFF_ADDED=0
    DIFF_REMOVED=0
    DIFF_MODIFIED=0
    DIFF_UNCHANGED=0
}

#--------------------------------------
# DIFF STRUCTURE
#--------------------------------------
# Compare expected folder structure with actual
diff_structure() {
    local vault_root="$1"
    local run_dir="$vault_root/Run"
    
    reset_diff_counters
    
    echo ""
    _diff_bold "📁 Structure Diff: $run_dir"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Check Run directory
    if [[ ! -d "$run_dir" ]]; then
        _diff_green "+ Run/"
        ((DIFF_ADDED++))
    else
        _diff_dim "= Run/"
        ((DIFF_UNCHANGED++))
    fi
    
    # Check Run-Hub.md
    if [[ ! -f "$vault_root/Run-Hub.md" ]]; then
        _diff_green "+ Run-Hub.md"
        ((DIFF_ADDED++))
    else
        _diff_dim "= Run-Hub.md"
        ((DIFF_UNCHANGED++))
    fi
    
    # Check each customer
    for cust_id in "${CUSTOMER_IDS[@]}"; do
        local cust_code
        cust_code=$(printf "CUST-%0${CUSTOMER_ID_WIDTH}d" "$cust_id")
        local cust_dir="$run_dir/$cust_code"
        
        if [[ ! -d "$cust_dir" ]]; then
            _diff_green "+ Run/$cust_code/"
            ((DIFF_ADDED++))
            
            # All sections would be added
            for section in "${SECTIONS[@]}"; do
                _diff_green "+   $cust_code-$section/"
                ((DIFF_ADDED++))
            done
        else
            _diff_dim "= Run/$cust_code/"
            ((DIFF_UNCHANGED++))
            
            # Check each section
            for section in "${SECTIONS[@]}"; do
                local section_dir="$cust_dir/$cust_code-$section"
                if [[ ! -d "$section_dir" ]]; then
                    _diff_green "+   $cust_code-$section/"
                    ((DIFF_ADDED++))
                else
                    _diff_dim "=   $cust_code-$section/"
                    ((DIFF_UNCHANGED++))
                fi
            done
        fi
    done
    
    # Check for orphan directories (would be removed if cleanup enabled)
    if [[ -d "$run_dir" ]] && [[ "$ENABLE_CLEANUP" == "true" ]]; then
        echo ""
        _diff_bold "🗑️  Orphan Detection (cleanup enabled):"
        
        for dir in "$run_dir"/CUST-*/; do
            [[ -d "$dir" ]] || continue
            local dir_name
            dir_name=$(basename "$dir")
            
            # Extract ID from CUST-XXX
            local dir_id="${dir_name#CUST-}"
            dir_id=$((10#$dir_id))  # Remove leading zeros
            
            # Check if ID is in config
            local found=false
            for cust_id in "${CUSTOMER_IDS[@]}"; do
                if [[ "$cust_id" -eq "$dir_id" ]]; then
                    found=true
                    break
                fi
            done
            
            if [[ "$found" == "false" ]]; then
                _diff_red "- Run/$dir_name/ (orphan)"
                ((DIFF_REMOVED++))
            fi
        done
    fi
    
    echo ""
}

#--------------------------------------
# DIFF TEMPLATES
#--------------------------------------
# Compare template files
diff_templates() {
    local vault_root="$1"
    local template_dir="$vault_root/${TEMPLATE_RELATIVE_ROOT#/}"
    
    echo ""
    _diff_bold "📄 Templates Diff: $template_dir"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Template files to check
    local -a template_files=(
        "CUST-Root-Index.md"
    )
    
    # Add section templates
    for section in "${SECTIONS[@]}"; do
        template_files+=("CUST-Section-$section-Index.md")
        template_files+=("RUN - New $section note.md")
    done
    
    for tpl_file in "${template_files[@]}"; do
        local tpl_path="$template_dir/$tpl_file"
        if [[ ! -f "$tpl_path" ]]; then
            _diff_green "+ $tpl_file"
            ((DIFF_ADDED++))
        else
            _diff_dim "= $tpl_file"
            ((DIFF_UNCHANGED++))
        fi
    done
    
    echo ""
}

#--------------------------------------
# DIFF APPLIED TEMPLATES
#--------------------------------------
# Show which index files would be created/updated
diff_applied_templates() {
    local vault_root="$1"
    local run_dir="$vault_root/Run"
    
    echo ""
    _diff_bold "📝 Applied Templates Diff:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    for cust_id in "${CUSTOMER_IDS[@]}"; do
        local cust_code
        cust_code=$(printf "CUST-%0${CUSTOMER_ID_WIDTH}d" "$cust_id")
        local cust_dir="$run_dir/$cust_code"
        
        # Root index
        local root_index="$cust_dir/$cust_code-Index.md"
        if [[ ! -f "$root_index" ]]; then
            _diff_green "+ $cust_code/$cust_code-Index.md"
            ((DIFF_ADDED++))
        else
            _diff_yellow "~ $cust_code/$cust_code-Index.md (will be overwritten)"
            ((DIFF_MODIFIED++))
        fi
        
        # Section indexes
        for section in "${SECTIONS[@]}"; do
            local section_index="$cust_dir/$cust_code-$section/$cust_code-$section-Index.md"
            if [[ ! -f "$section_index" ]]; then
                _diff_green "+   $cust_code-$section/$cust_code-$section-Index.md"
                ((DIFF_ADDED++))
            else
                _diff_yellow "~   $cust_code-$section/$cust_code-$section-Index.md"
                ((DIFF_MODIFIED++))
            fi
        done
    done
    
    echo ""
}

#--------------------------------------
# SHOW DIFF SUMMARY
#--------------------------------------
show_diff_summary() {
    echo ""
    _diff_bold "📊 Summary:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [[ $DIFF_ADDED -gt 0 ]]; then
        _diff_green "  + $DIFF_ADDED to add"
    fi
    if [[ $DIFF_MODIFIED -gt 0 ]]; then
        _diff_yellow "  ~ $DIFF_MODIFIED to modify"
    fi
    if [[ $DIFF_REMOVED -gt 0 ]]; then
        _diff_red "  - $DIFF_REMOVED to remove"
    fi
    if [[ $DIFF_UNCHANGED -gt 0 ]]; then
        _diff_dim "  = $DIFF_UNCHANGED unchanged"
    fi
    
    local total=$((DIFF_ADDED + DIFF_MODIFIED + DIFF_REMOVED))
    if [[ $total -eq 0 ]]; then
        echo ""
        _diff_cyan "  ✓ Everything is up to date!"
    else
        echo ""
        echo "  Total changes: $total"
    fi
    
    echo ""
}

#--------------------------------------
# FULL DIFF REPORT
#--------------------------------------
run_full_diff() {
    local vault_root="$1"
    local mode="${2:-all}"  # all, structure, templates
    
    reset_diff_counters
    
    _diff_cyan "╔══════════════════════════════════════════════════════════════╗"
    _diff_cyan "║                     DIFF PREVIEW                             ║"
    _diff_cyan "╚══════════════════════════════════════════════════════════════╝"
    
    case "$mode" in
        structure)
            diff_structure "$vault_root"
            ;;
        templates)
            diff_templates "$vault_root"
            diff_applied_templates "$vault_root"
            ;;
        all|*)
            diff_structure "$vault_root"
            diff_templates "$vault_root"
            diff_applied_templates "$vault_root"
            ;;
    esac
    
    show_diff_summary
    
    # Return 1 if there are changes, 0 if none
    local total=$((DIFF_ADDED + DIFF_MODIFIED + DIFF_REMOVED))
    [[ $total -eq 0 ]]
}
