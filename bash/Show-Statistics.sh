#!/usr/bin/env bash
#===============================================================================
#
#  AUTOVAULT - Show-Statistics.sh
#
#===============================================================================
#
#  DESCRIPTION:    Shows detailed statistics and analytics for the vault.
#                  Provides insights into usage, growth, and health.
#
#  STATISTICS:     - Total files and folders count
#                  - Disk usage per customer/section
#                  - Template coverage analysis
#                  - Recent activity (modified files)
#                  - Backup history
#                  - Growth trends (if git tracked)
#
#  USAGE:          Called via: ./cust-run-config.sh stats
#                  Direct:     bash/Show-Statistics.sh
#
#  DEPENDENCIES:   bash/lib/logging.sh, bash/lib/config.sh, jq
#
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/config.sh"

#--------------------------------------
# HELPER FUNCTIONS
#--------------------------------------
human_size() {
    local bytes=$1
    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes}B"
    elif [[ $bytes -lt 1048576 ]]; then
        echo "$(( bytes / 1024 ))KB"
    elif [[ $bytes -lt 1073741824 ]]; then
        echo "$(( bytes / 1048576 ))MB"
    else
        echo "$(( bytes / 1073741824 ))GB"
    fi
}

progress_bar() {
    local current=$1
    local total=$2
    local width=${3:-20}
    
    if [[ $total -eq 0 ]]; then
        printf "[%${width}s]" ""
        return
    fi
    
    local percent=$(( current * 100 / total ))
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))
    
    printf "["
    printf "%0.s█" $(seq 1 $filled 2>/dev/null) || true
    printf "%0.s░" $(seq 1 $empty 2>/dev/null) || true
    printf "] %3d%%" "$percent"
}

#--------------------------------------
# MAIN STATISTICS
#--------------------------------------
show_statistics() {
    # Normalize vault path
    local vault_path="$VAULT_ROOT"
    vault_path="${vault_path/#\~/$HOME}"
    [[ "$vault_path" == *"\\"* ]] && vault_path="${vault_path//\\//}"
    
    local run_dir="$vault_path/Run"
    
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                ${BOLD}📊 AutoVault Statistics${NC}                       ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    #--------------------------------------
    # Quick Overview
    #--------------------------------------
    echo -e "${BOLD}📋 Quick Overview${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local total_customers=${#CUSTOMER_IDS[@]}
    local total_sections=${#SECTIONS[@]}
    local expected_folders=$(( total_customers * (1 + total_sections) + 1 ))  # +1 for Run dir
    
    printf "  Configured Customers:  ${BOLD}%d${NC}\n" "$total_customers"
    printf "  Configured Sections:   ${BOLD}%d${NC}\n" "$total_sections"
    printf "  Expected Folders:      ${BOLD}%d${NC}\n" "$expected_folders"
    echo ""
    
    #--------------------------------------
    # Vault Analysis
    #--------------------------------------
    if [[ -d "$run_dir" ]]; then
        echo -e "${BOLD}📁 Vault Analysis${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Count actual directories and files
        local actual_cust_dirs=0
        local actual_section_dirs=0
        local total_md_files=0
        local total_other_files=0
        local total_size=0
        
        # Analyze each customer
        for dir in "$run_dir"/CUST-*/; do
            [[ -d "$dir" ]] || continue
            ((actual_cust_dirs++)) || true
            
            # Count section directories
            for subdir in "$dir"*/; do
                [[ -d "$subdir" ]] || continue
                ((actual_section_dirs++)) || true
            done
            
            # Count files
            local md_count
            md_count=$(find "$dir" -type f -name "*.md" 2>/dev/null | wc -l)
            local other_count
            other_count=$(find "$dir" -type f ! -name "*.md" 2>/dev/null | wc -l)
            
            total_md_files=$((total_md_files + md_count))
            total_other_files=$((total_other_files + other_count))
            
            # Get size
            local dir_size
            dir_size=$(du -sb "$dir" 2>/dev/null | cut -f1 || echo "0")
            total_size=$((total_size + dir_size))
        done
        
        printf "  Customer Directories:  %d / %d " "$actual_cust_dirs" "$total_customers"
        progress_bar "$actual_cust_dirs" "$total_customers"
        echo ""
        
        printf "  Section Directories:   %d / %d " "$actual_section_dirs" "$((total_customers * total_sections))"
        progress_bar "$actual_section_dirs" "$((total_customers * total_sections))"
        echo ""
        
        printf "  Markdown Files:        ${BOLD}%d${NC}\n" "$total_md_files"
        printf "  Other Files:           %d\n" "$total_other_files"
        printf "  Total Vault Size:      ${BOLD}%s${NC}\n" "$(human_size $total_size)"
        echo ""
        
        #--------------------------------------
        # Per-Customer Stats
        #--------------------------------------
        if [[ "$actual_cust_dirs" -gt 0 ]]; then
            echo -e "${BOLD}👥 Per-Customer Statistics${NC}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            
            # Table header
            printf "  %-12s  %6s  %6s  %8s  %s\n" "Customer" "Files" "Notes" "Size" "Status"
            printf "  %-12s  %6s  %6s  %8s  %s\n" "────────────" "──────" "──────" "────────" "────────"
            
            for id in "${CUSTOMER_IDS[@]}"; do
                local cust_code
                cust_code=$(printf "CUST-%0${CUSTOMER_ID_WIDTH}d" "$id")
                local cust_dir="$run_dir/$cust_code"
                
                if [[ -d "$cust_dir" ]]; then
                    local file_count
                    file_count=$(find "$cust_dir" -type f 2>/dev/null | wc -l)
                    local note_count
                    note_count=$(find "$cust_dir" -type f -name "*.md" 2>/dev/null | wc -l)
                    local cust_size
                    cust_size=$(du -sb "$cust_dir" 2>/dev/null | cut -f1 || echo "0")
                    
                    # Check completeness
                    local sections_present=0
                    for section in "${SECTIONS[@]}"; do
                        [[ -d "$cust_dir/$cust_code-$section" ]] && { ((sections_present++)) || true; }
                    done
                    
                    local status
                    if [[ $sections_present -eq $total_sections ]]; then
                        status="${GREEN}✓ Complete${NC}"
                    else
                        status="${YELLOW}! ${sections_present}/${total_sections} sections${NC}"
                    fi
                    
                    printf "  %-12s  %6d  %6d  %8s  %b\n" \
                        "$cust_code" "$file_count" "$note_count" "$(human_size $cust_size)" "$status"
                else
                    printf "  %-12s  %6s  %6s  %8s  %b\n" \
                        "$cust_code" "-" "-" "-" "${RED}✗ Missing${NC}"
                fi
            done
            echo ""
        fi
        
        #--------------------------------------
        # Section Distribution
        #--------------------------------------
        echo -e "${BOLD}📂 Section Distribution${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        for section in "${SECTIONS[@]}"; do
            local section_count=0
            local section_files=0
            local section_size=0
            
            for id in "${CUSTOMER_IDS[@]}"; do
                local cust_code
                cust_code=$(printf "CUST-%0${CUSTOMER_ID_WIDTH}d" "$id")
                local section_dir="$run_dir/$cust_code/$cust_code-$section"
                
                if [[ -d "$section_dir" ]]; then
                    ((section_count++)) || true
                    local files
                    files=$(find "$section_dir" -type f 2>/dev/null | wc -l)
                    section_files=$((section_files + files))
                    local size
                    size=$(du -sb "$section_dir" 2>/dev/null | cut -f1 || echo "0")
                    section_size=$((section_size + size))
                fi
            done
            
            printf "  %-15s  %3d/%d dirs  %4d files  %8s\n" \
                "$section" "$section_count" "$total_customers" "$section_files" "$(human_size $section_size)"
        done
        echo ""
        
        #--------------------------------------
        # Recent Activity
        #--------------------------------------
        echo -e "${BOLD}🕐 Recent Activity (last 7 days)${NC}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        local recent_files
        recent_files=$(find "$run_dir" -type f -mtime -7 2>/dev/null | wc -l)
        local recent_dirs
        recent_dirs=$(find "$run_dir" -type d -mtime -7 2>/dev/null | wc -l)
        
        printf "  Modified Files:        %d\n" "$recent_files"
        printf "  Modified Directories:  %d\n" "$recent_dirs"
        
        # Show 5 most recently modified files
        echo ""
        echo "  Most Recent Changes:"
        find "$run_dir" -type f -name "*.md" -mtime -7 -printf "    %T+ %p\n" 2>/dev/null | \
            sort -r | head -5 | \
            while read -r line; do
                local date="${line%% *}"
                local file="${line#* }"
                file="${file#$run_dir/}"
                date="${date%%.*}"
                echo -e "    ${DIM}${date}${NC}  $file"
            done || echo "    (no recent changes)"
        echo ""
    else
        echo -e "${YELLOW}⚠ Run directory not found. Run 'structure' first.${NC}"
        echo ""
    fi
    
    #--------------------------------------
    # Backup Statistics
    #--------------------------------------
    echo -e "${BOLD}💾 Backup Statistics${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [[ -d "$BACKUP_DIR" ]]; then
        local backup_count
        backup_count=$(find "$BACKUP_DIR" -maxdepth 1 -name "*.json" -type f 2>/dev/null | wc -l)
        local backup_size
        backup_size=$(du -sb "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo "0")
        
        printf "  Total Backups:         %d\n" "$backup_count"
        printf "  Backup Directory Size: %s\n" "$(human_size $backup_size)"
        
        if [[ $backup_count -gt 0 ]]; then
            local oldest
            oldest=$(find "$BACKUP_DIR" -maxdepth 1 -name "*.json" -type f -printf "%T+ %f\n" 2>/dev/null | sort | head -1 | cut -d' ' -f2)
            local newest
            newest=$(find "$BACKUP_DIR" -maxdepth 1 -name "*.json" -type f -printf "%T+ %f\n" 2>/dev/null | sort -r | head -1 | cut -d' ' -f2)
            
            printf "  Oldest Backup:         %s\n" "${oldest%.json}"
            printf "  Newest Backup:         %s\n" "${newest%.json}"
        fi
    else
        printf "  ${DIM}No backups found${NC}\n"
    fi
    echo ""
    
    #--------------------------------------
    # Template Coverage
    #--------------------------------------
    echo -e "${BOLD}📝 Template Coverage${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local template_dir="$vault_path/${TEMPLATE_RELATIVE_ROOT#/}"
    if [[ -d "$template_dir" ]]; then
        local tpl_count
        tpl_count=$(find "$template_dir" -type f -name "*.md" 2>/dev/null | wc -l)
        printf "  Template Directory:    ${GREEN}✓${NC} exists\n"
        printf "  Template Files:        %d\n" "$tpl_count"
        
        # Check expected templates
        local expected_tpls=1  # Root template
        expected_tpls=$((expected_tpls + total_sections * 2))  # Section + Note per section
        
        printf "  Template Coverage:     %d / %d " "$tpl_count" "$expected_tpls"
        progress_bar "$tpl_count" "$expected_tpls"
        echo ""
    else
        printf "  Template Directory:    ${YELLOW}!${NC} not found\n"
        printf "  ${DIM}Run 'templates sync' to create templates${NC}\n"
    fi
    echo ""
    
    #--------------------------------------
    # Health Score
    #--------------------------------------
    echo -e "${BOLD}🏥 Health Score${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local health_score=0
    local health_max=100
    
    # Config exists (+20)
    [[ -f "$CONFIG_JSON" ]] && health_score=$((health_score + 20))
    
    # Vault exists (+10)
    [[ -d "$vault_path" ]] && health_score=$((health_score + 10))
    
    # Run dir exists (+10)
    [[ -d "$run_dir" ]] && health_score=$((health_score + 10))
    
    # All customers have dirs (+30)
    if [[ "$actual_cust_dirs" -eq "$total_customers" ]] && [[ "$total_customers" -gt 0 ]]; then
        health_score=$((health_score + 30))
    elif [[ "$total_customers" -gt 0 ]]; then
        health_score=$((health_score + (30 * actual_cust_dirs / total_customers)))
    fi
    
    # Templates exist (+20)
    [[ -d "$template_dir" ]] && health_score=$((health_score + 20))
    
    # Has backups (+10)
    [[ -d "$BACKUP_DIR" ]] && [[ $(find "$BACKUP_DIR" -maxdepth 1 -name "*.json" -type f 2>/dev/null | wc -l) -gt 0 ]] && health_score=$((health_score + 10))
    
    printf "  Overall Health:        "
    progress_bar "$health_score" "$health_max" 30
    echo ""
    
    if [[ $health_score -ge 90 ]]; then
        echo -e "  ${GREEN}★★★★★ Excellent!${NC} Your vault is in great shape."
    elif [[ $health_score -ge 70 ]]; then
        echo -e "  ${GREEN}★★★★☆ Good${NC} - Minor improvements possible."
    elif [[ $health_score -ge 50 ]]; then
        echo -e "  ${YELLOW}★★★☆☆ Fair${NC} - Some attention needed."
    elif [[ $health_score -ge 30 ]]; then
        echo -e "  ${YELLOW}★★☆☆☆ Needs Work${NC} - Run structure and templates commands."
    else
        echo -e "  ${RED}★☆☆☆☆ Critical${NC} - Run 'vault init' to set up."
    fi
    echo ""
}

#--------------------------------------
# MAIN
#--------------------------------------
# Load configuration
if ! load_config; then
    log_error "Failed to load configuration"
    exit 1
fi

show_statistics
