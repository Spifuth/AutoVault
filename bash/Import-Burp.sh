#!/usr/bin/env bash
#===============================================================================
#
#  AUTOVAULT - Import-Burp.sh
#
#===============================================================================
#
#  DESCRIPTION:    Import Burp Suite scan results into customer folders.
#                  Parses Burp XML export files and generates structured
#                  Markdown notes for Obsidian integration.
#
#  USAGE:          ./Import-Burp.sh import <file.xml> --customer <ID>
#                  ./Import-Burp.sh parse <file.xml>
#                  ./Import-Burp.sh templates list
#
#  FORMATS:        - Burp Suite XML export (Issues/Vulnerabilities)
#                  - Burp Suite HTML report (converted)
#
#  OUTPUT:         - Markdown summary with all findings
#                  - Per-vulnerability detail files
#                  - Severity-based organization
#                  - Dataview-compatible frontmatter
#
#  REQUIREMENTS:   - Bash 4+
#                  - xmllint (libxml2-utils) for XML parsing
#                  - jq (optional, for JSON processing)
#
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source libraries
source "$SCRIPT_DIR/lib/logging.sh" 2>/dev/null || source "$PROJECT_ROOT/bash/lib/logging.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/ui.sh" 2>/dev/null || source "$PROJECT_ROOT/bash/lib/ui.sh" 2>/dev/null || true
source "$SCRIPT_DIR/lib/config.sh" 2>/dev/null || source "$PROJECT_ROOT/bash/lib/config.sh" 2>/dev/null || true

# Configuration
CONFIG_JSON="${CONFIG_JSON:-$PROJECT_ROOT/config/cust-run-config.json}"
QUIET_MODE=false
VERBOSE_MODE=false
DRY_RUN=false

# Burp severity levels
declare -A SEVERITY_COLORS=(
    ["High"]="🔴"
    ["Medium"]="🟠"
    ["Low"]="🟡"
    ["Information"]="🔵"
    ["Info"]="🔵"
)

declare -A SEVERITY_ORDER=(
    ["High"]=1
    ["Medium"]=2
    ["Low"]=3
    ["Information"]=4
    ["Info"]=4
)

#######################################
# Logging functions (fallback if not sourced)
#######################################

log_info() {
    [[ "$QUIET_MODE" == "true" ]] && return
    echo -e "\033[0;34m[INFO]\033[0m $*"
}

log_success() {
    [[ "$QUIET_MODE" == "true" ]] && return
    echo -e "\033[0;32m[OK]\033[0m $*"
}

log_warn() {
    echo -e "\033[0;33m[WARN]\033[0m $*" >&2
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $*" >&2
}

log_debug() {
    [[ "$VERBOSE_MODE" != "true" ]] && return
    echo -e "\033[0;90m[DEBUG]\033[0m $*"
}

#######################################
# Show usage
#######################################
show_usage() {
    cat << 'EOF'
Usage: Import-Burp.sh <command> [options]

Commands:
  import <file>    Import Burp Suite XML into customer folder
  parse <file>     Parse and display findings (preview)
  templates        Manage Burp report templates

Options:
  -c, --customer <ID>    Target customer ID (required for import)
  -o, --output-dir <dir> Custom output directory
  -f, --format <type>    Input format: xml (default), html
  --severity <level>     Filter by minimum severity (High/Medium/Low/Info)
  --raw                  Preserve original XML file
  --no-summary           Skip summary generation
  -q, --quiet            Suppress output
  -v, --verbose          Enable debug output
  --dry-run              Preview without writing files
  -h, --help             Show this help

Examples:
  # Import Burp scan for customer
  Import-Burp.sh import burp-scan.xml --customer CUST-001

  # Preview findings without importing
  Import-Burp.sh parse burp-export.xml

  # Import only High/Medium findings
  Import-Burp.sh import scan.xml -c CUST-002 --severity Medium

  # Custom output directory
  Import-Burp.sh import scan.xml -c CUST-001 -o ./reports

Burp Export Instructions:
  1. In Burp Suite: Target > Site map > Right-click > Issues > Report issues
  2. Select XML format
  3. Choose "Base64-encode requests and responses" for full data
  4. Save as .xml file
EOF
}

#######################################
# Check dependencies
#######################################
check_dependencies() {
    local missing=()
    
    if ! command -v xmllint &>/dev/null; then
        missing+=("xmllint (libxml2-utils)")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_info "Install with: sudo apt install libxml2-utils"
        return 1
    fi
    
    return 0
}

#######################################
# Validate Burp XML file
#######################################
validate_burp_xml() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi
    
    # Check if it's valid XML
    if ! xmllint --noout "$file" 2>/dev/null; then
        log_error "Invalid XML file: $file"
        return 1
    fi
    
    # Check for Burp Suite markers
    if grep -q "<issues\|<issue\|burpVersion" "$file" 2>/dev/null; then
        log_debug "Valid Burp Suite XML detected"
        return 0
    fi
    
    log_warn "File may not be a Burp Suite export"
    return 0
}

#######################################
# Parse Burp XML and extract issues
#######################################
parse_burp_xml() {
    local file="$1"
    local min_severity="${2:-}"
    
    log_info "Parsing Burp Suite XML: $file"
    
    # Extract issue count
    local issue_count
    issue_count=$(xmllint --xpath 'count(//issue)' "$file" 2>/dev/null || echo "0")
    
    if [[ "$issue_count" == "0" ]]; then
        log_warn "No issues found in Burp export"
        return 0
    fi
    
    log_info "Found $issue_count issues"
    
    # Extract issues data
    local i=1
    while [[ $i -le $issue_count ]]; do
        local name severity confidence host path
        
        name=$(xmllint --xpath "string(//issue[$i]/name)" "$file" 2>/dev/null || echo "Unknown")
        severity=$(xmllint --xpath "string(//issue[$i]/severity)" "$file" 2>/dev/null || echo "Information")
        confidence=$(xmllint --xpath "string(//issue[$i]/confidence)" "$file" 2>/dev/null || echo "Tentative")
        host=$(xmllint --xpath "string(//issue[$i]/host)" "$file" 2>/dev/null || echo "")
        path=$(xmllint --xpath "string(//issue[$i]/path)" "$file" 2>/dev/null || echo "/")
        
        # Filter by severity if specified
        if [[ -n "$min_severity" ]]; then
            local min_order=${SEVERITY_ORDER[$min_severity]:-4}
            local issue_order=${SEVERITY_ORDER[$severity]:-4}
            if [[ $issue_order -gt $min_order ]]; then
                ((i++))
                continue
            fi
        fi
        
        local icon="${SEVERITY_COLORS[$severity]:-⚪}"
        echo "$icon|$severity|$confidence|$name|$host$path"
        
        ((i++))
    done
}

#######################################
# Extract full issue details
#######################################
extract_issue_details() {
    local file="$1"
    local index="$2"
    
    local name severity confidence host path
    local issueBackground remediationBackground issueDetail
    local request response
    
    name=$(xmllint --xpath "string(//issue[$index]/name)" "$file" 2>/dev/null || echo "Unknown")
    severity=$(xmllint --xpath "string(//issue[$index]/severity)" "$file" 2>/dev/null || echo "Information")
    confidence=$(xmllint --xpath "string(//issue[$index]/confidence)" "$file" 2>/dev/null || echo "Tentative")
    host=$(xmllint --xpath "string(//issue[$index]/host)" "$file" 2>/dev/null || echo "")
    path=$(xmllint --xpath "string(//issue[$index]/path)" "$file" 2>/dev/null || echo "/")
    
    issueBackground=$(xmllint --xpath "string(//issue[$index]/issueBackground)" "$file" 2>/dev/null || echo "")
    remediationBackground=$(xmllint --xpath "string(//issue[$index]/remediationBackground)" "$file" 2>/dev/null || echo "")
    issueDetail=$(xmllint --xpath "string(//issue[$index]/issueDetail)" "$file" 2>/dev/null || echo "")
    
    # Try to get request/response (may be base64 encoded)
    request=$(xmllint --xpath "string(//issue[$index]/requestresponse/request)" "$file" 2>/dev/null || echo "")
    response=$(xmllint --xpath "string(//issue[$index]/requestresponse/response)" "$file" 2>/dev/null || echo "")
    
    # Output as simple format for processing
    cat << EOF
NAME:$name
SEVERITY:$severity
CONFIDENCE:$confidence
HOST:$host
PATH:$path
BACKGROUND:$issueBackground
REMEDIATION:$remediationBackground
DETAIL:$issueDetail
REQUEST:$request
RESPONSE:$response
EOF
}

#######################################
# Generate Markdown for a single issue
#######################################
generate_issue_markdown() {
    local name="$1"
    local severity="$2"
    local confidence="$3"
    local host="$4"
    local path="$5"
    local background="$6"
    local remediation="$7"
    local detail="$8"
    local request="$9"
    local response="${10:-}"
    
    local date_now
    date_now=$(date +%Y-%m-%d)
    local icon="${SEVERITY_COLORS[$severity]:-⚪}"
    
    # Clean HTML from background/remediation
    background=$(echo "$background" | sed 's/<[^>]*>//g' | sed 's/&lt;/</g; s/&gt;/>/g; s/&amp;/\&/g; s/&quot;/"/g')
    remediation=$(echo "$remediation" | sed 's/<[^>]*>//g' | sed 's/&lt;/</g; s/&gt;/>/g; s/&amp;/\&/g; s/&quot;/"/g')
    detail=$(echo "$detail" | sed 's/<[^>]*>//g' | sed 's/&lt;/</g; s/&gt;/>/g; s/&amp;/\&/g; s/&quot;/"/g')
    
    cat << EOF
---
type: vulnerability
source: burp-suite
severity: $severity
confidence: $confidence
host: "$host"
path: "$path"
date: $date_now
tags:
  - burp
  - vulnerability
  - $severity
---

# $icon $name

## Overview

| Property | Value |
|----------|-------|
| **Severity** | $icon $severity |
| **Confidence** | $confidence |
| **Host** | \`$host\` |
| **Path** | \`$path\` |
| **Date** | $date_now |

## Description

$background

## Issue Detail

$detail

## Remediation

$remediation

EOF

    # Add request/response if available
    if [[ -n "$request" && "$request" != "null" ]]; then
        # Check if base64 encoded
        if [[ "$request" =~ ^[A-Za-z0-9+/=]+$ ]] && [[ ${#request} -gt 50 ]]; then
            local decoded
            decoded=$(echo "$request" | base64 -d 2>/dev/null || echo "$request")
            cat << EOF
## HTTP Request

\`\`\`http
$decoded
\`\`\`

EOF
        else
            cat << EOF
## HTTP Request

\`\`\`http
$request
\`\`\`

EOF
        fi
    fi
    
    if [[ -n "$response" && "$response" != "null" ]]; then
        # Truncate long responses
        local resp_preview
        if [[ "$response" =~ ^[A-Za-z0-9+/=]+$ ]] && [[ ${#response} -gt 50 ]]; then
            resp_preview=$(echo "$response" | base64 -d 2>/dev/null | head -c 2000 || echo "[Response truncated]")
        else
            resp_preview=$(echo "$response" | head -c 2000)
        fi
        
        cat << EOF
## HTTP Response (Preview)

\`\`\`http
$resp_preview
...
\`\`\`

EOF
    fi
    
    cat << EOF
---

## Notes

> Add your analysis notes here

## Status

- [ ] Confirmed
- [ ] Exploited
- [ ] Reported
- [ ] Fixed
- [ ] Verified

EOF
}

#######################################
# Generate summary Markdown
#######################################
generate_summary_markdown() {
    local scan_file="$1"
    local output_dir="$2"
    local customer_id="$3"
    
    local date_now time_now
    date_now=$(date +%Y-%m-%d)
    time_now=$(date +%H:%M:%S)
    
    local issue_count
    issue_count=$(xmllint --xpath 'count(//issue)' "$scan_file" 2>/dev/null || echo "0")
    
    # Count by severity
    local high_count medium_count low_count info_count
    high_count=$(xmllint --xpath 'count(//issue[severity="High"])' "$scan_file" 2>/dev/null || echo "0")
    medium_count=$(xmllint --xpath 'count(//issue[severity="Medium"])' "$scan_file" 2>/dev/null || echo "0")
    low_count=$(xmllint --xpath 'count(//issue[severity="Low"])' "$scan_file" 2>/dev/null || echo "0")
    info_count=$(xmllint --xpath 'count(//issue[severity="Information"])' "$scan_file" 2>/dev/null || echo "0")
    
    # Get Burp version if available
    local burp_version
    burp_version=$(xmllint --xpath 'string(//issues/@burpVersion)' "$scan_file" 2>/dev/null || echo "Unknown")
    
    # Get unique hosts
    local hosts
    hosts=$(xmllint --xpath '//issue/host/text()' "$scan_file" 2>/dev/null | sort -u | tr '\n' ', ' | sed 's/,$//' || echo "N/A")
    
    cat << EOF
---
type: burp-scan
source: burp-suite
customer: $customer_id
date: $date_now
total_issues: $issue_count
high: $high_count
medium: $medium_count
low: $low_count
info: $info_count
tags:
  - burp
  - scan
  - security-assessment
---

# 🔒 Burp Suite Scan Results

## Scan Information

| Property | Value |
|----------|-------|
| **Customer** | $customer_id |
| **Date** | $date_now $time_now |
| **Burp Version** | $burp_version |
| **Total Issues** | $issue_count |
| **Targets** | $hosts |

## Severity Summary

| Severity | Count | Percentage |
|----------|-------|------------|
| 🔴 High | $high_count | $(awk "BEGIN {printf \"%.1f\", ($high_count/$issue_count)*100}")% |
| 🟠 Medium | $medium_count | $(awk "BEGIN {printf \"%.1f\", ($medium_count/$issue_count)*100}")% |
| 🟡 Low | $low_count | $(awk "BEGIN {printf \"%.1f\", ($low_count/$issue_count)*100}")% |
| 🔵 Info | $info_count | $(awk "BEGIN {printf \"%.1f\", ($info_count/$issue_count)*100}")% |

## Risk Distribution

\`\`\`
High:   $( printf '█%.0s' $(seq 1 $((high_count > 0 ? high_count : 0))) ) ($high_count)
Medium: $( printf '█%.0s' $(seq 1 $((medium_count > 0 ? medium_count : 0))) ) ($medium_count)
Low:    $( printf '█%.0s' $(seq 1 $((low_count > 0 ? low_count : 0))) ) ($low_count)
Info:   $( printf '█%.0s' $(seq 1 $((info_count > 0 ? info_count : 0))) ) ($info_count)
\`\`\`

## Findings

EOF

    # List all issues grouped by severity
    for sev in "High" "Medium" "Low" "Information"; do
        local sev_icon="${SEVERITY_COLORS[$sev]:-⚪}"
        local count
        count=$(xmllint --xpath "count(//issue[severity=\"$sev\"])" "$scan_file" 2>/dev/null || echo "0")
        
        if [[ "$count" != "0" ]]; then
            echo "### $sev_icon $sev ($count)"
            echo ""
            
            local i=1
            local issue_index=1
            local total_issues
            total_issues=$(xmllint --xpath 'count(//issue)' "$scan_file" 2>/dev/null || echo "0")
            
            while [[ $issue_index -le $total_issues ]]; do
                local issue_sev
                issue_sev=$(xmllint --xpath "string(//issue[$issue_index]/severity)" "$scan_file" 2>/dev/null || echo "")
                
                if [[ "$issue_sev" == "$sev" ]]; then
                    local name host path
                    name=$(xmllint --xpath "string(//issue[$issue_index]/name)" "$scan_file" 2>/dev/null || echo "Unknown")
                    host=$(xmllint --xpath "string(//issue[$issue_index]/host)" "$scan_file" 2>/dev/null || echo "")
                    path=$(xmllint --xpath "string(//issue[$issue_index]/path)" "$scan_file" 2>/dev/null || echo "/")
                    
                    # Create safe filename
                    local safe_name
                    safe_name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | head -c 50)
                    
                    echo "- [[$safe_name|$name]] - \`$host$path\`"
                fi
                
                ((issue_index++))
            done
            echo ""
        fi
    done
    
    cat << EOF

---

## Dataview Queries

### All High Severity Issues

\`\`\`dataview
TABLE severity, confidence, host, path
FROM "$customer_id/Vulnerabilities/Burp"
WHERE severity = "High"
SORT file.name ASC
\`\`\`

### Issues by Host

\`\`\`dataview
TABLE severity, file.name as "Issue"
FROM "$customer_id/Vulnerabilities/Burp"
WHERE type = "vulnerability"
GROUP BY host
\`\`\`

### Status Tracking

\`\`\`dataview
TABLE severity, host, path
FROM "$customer_id/Vulnerabilities/Burp"
WHERE !contains(file.tasks.completed, true)
SORT severity ASC
\`\`\`

---

## Assessment Notes

> Add your overall assessment notes here

## Recommendations

1. 
2. 
3. 

EOF
}

#######################################
# Import Burp scan to customer folder
#######################################
do_import() {
    local file="$1"
    local customer_id="$2"
    local output_dir="${3:-}"
    local min_severity="${4:-}"
    local keep_raw="${5:-false}"
    local skip_summary="${6:-false}"
    
    # Validate file
    if ! validate_burp_xml "$file"; then
        return 1
    fi
    
    # Check dependencies
    if ! check_dependencies; then
        return 1
    fi
    
    # Determine output directory
    if [[ -z "$output_dir" ]]; then
        # Get vault root from config
        local vault_root
        if [[ -f "$CONFIG_JSON" ]]; then
            vault_root=$(jq -r '.VaultRoot // empty' "$CONFIG_JSON" 2>/dev/null || echo "")
        fi
        
        if [[ -z "$vault_root" ]]; then
            log_error "No vault root configured. Use -o to specify output directory"
            return 1
        fi
        
        output_dir="$vault_root/$customer_id/Vulnerabilities/Burp"
    fi
    
    log_info "Importing to: $output_dir"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warn "DRY RUN - No files will be created"
    fi
    
    # Create output directories
    if [[ "$DRY_RUN" != "true" ]]; then
        mkdir -p "$output_dir/findings"
    fi
    
    # Get issue count
    local issue_count
    issue_count=$(xmllint --xpath 'count(//issue)' "$file" 2>/dev/null || echo "0")
    
    if [[ "$issue_count" == "0" ]]; then
        log_warn "No issues found in Burp export"
        return 0
    fi
    
    log_info "Processing $issue_count issues..."
    
    # Process each issue
    local i=1
    local created=0
    local skipped=0
    
    while [[ $i -le $issue_count ]]; do
        local name severity confidence host path
        local background remediation detail request response
        
        name=$(xmllint --xpath "string(//issue[$i]/name)" "$file" 2>/dev/null || echo "Unknown")
        severity=$(xmllint --xpath "string(//issue[$i]/severity)" "$file" 2>/dev/null || echo "Information")
        confidence=$(xmllint --xpath "string(//issue[$i]/confidence)" "$file" 2>/dev/null || echo "Tentative")
        host=$(xmllint --xpath "string(//issue[$i]/host)" "$file" 2>/dev/null || echo "")
        path=$(xmllint --xpath "string(//issue[$i]/path)" "$file" 2>/dev/null || echo "/")
        
        # Filter by severity
        if [[ -n "$min_severity" ]]; then
            local min_order=${SEVERITY_ORDER[$min_severity]:-4}
            local issue_order=${SEVERITY_ORDER[$severity]:-4}
            if [[ $issue_order -gt $min_order ]]; then
                ((skipped++))
                ((i++))
                continue
            fi
        fi
        
        background=$(xmllint --xpath "string(//issue[$i]/issueBackground)" "$file" 2>/dev/null || echo "")
        remediation=$(xmllint --xpath "string(//issue[$i]/remediationBackground)" "$file" 2>/dev/null || echo "")
        detail=$(xmllint --xpath "string(//issue[$i]/issueDetail)" "$file" 2>/dev/null || echo "")
        request=$(xmllint --xpath "string(//issue[$i]/requestresponse/request)" "$file" 2>/dev/null || echo "")
        response=$(xmllint --xpath "string(//issue[$i]/requestresponse/response)" "$file" 2>/dev/null || echo "")
        
        # Create safe filename
        local safe_name
        safe_name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-' | head -c 50)
        
        # Add index if duplicate
        local finding_file="$output_dir/findings/${safe_name}.md"
        if [[ -f "$finding_file" ]]; then
            finding_file="$output_dir/findings/${safe_name}-$i.md"
        fi
        
        log_debug "Creating: $finding_file"
        
        if [[ "$DRY_RUN" != "true" ]]; then
            generate_issue_markdown "$name" "$severity" "$confidence" "$host" "$path" \
                "$background" "$remediation" "$detail" "$request" "$response" > "$finding_file"
        fi
        
        ((created++))
        ((i++))
    done
    
    # Generate summary
    if [[ "$skip_summary" != "true" ]]; then
        local date_stamp
        date_stamp=$(date +%Y-%m-%d)
        local summary_file="$output_dir/${date_stamp}_burp-summary.md"
        
        log_info "Generating summary: $summary_file"
        
        if [[ "$DRY_RUN" != "true" ]]; then
            generate_summary_markdown "$file" "$output_dir" "$customer_id" > "$summary_file"
        fi
    fi
    
    # Copy raw file if requested
    if [[ "$keep_raw" == "true" && "$DRY_RUN" != "true" ]]; then
        local raw_file
        raw_file="$output_dir/$(basename "$file")"
        cp "$file" "$raw_file"
        log_info "Saved raw file: $raw_file"
    fi
    
    log_success "Import complete!"
    log_info "  Created: $created finding(s)"
    [[ $skipped -gt 0 ]] && log_info "  Skipped: $skipped (filtered by severity)"
    log_info "  Location: $output_dir"
}

#######################################
# Parse and display (preview mode)
#######################################
do_parse() {
    local file="$1"
    local min_severity="${2:-}"
    
    if ! validate_burp_xml "$file"; then
        return 1
    fi
    
    if ! check_dependencies; then
        return 1
    fi
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║              🔒 Burp Suite Scan Results                        ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Get counts
    local total high medium low info
    total=$(xmllint --xpath 'count(//issue)' "$file" 2>/dev/null || echo "0")
    high=$(xmllint --xpath 'count(//issue[severity="High"])' "$file" 2>/dev/null || echo "0")
    medium=$(xmllint --xpath 'count(//issue[severity="Medium"])' "$file" 2>/dev/null || echo "0")
    low=$(xmllint --xpath 'count(//issue[severity="Low"])' "$file" 2>/dev/null || echo "0")
    info=$(xmllint --xpath 'count(//issue[severity="Information"])' "$file" 2>/dev/null || echo "0")
    
    echo "📊 Summary"
    echo "   Total Issues: $total"
    echo "   🔴 High: $high | 🟠 Medium: $medium | 🟡 Low: $low | 🔵 Info: $info"
    echo ""
    
    echo "📋 Findings"
    echo "─────────────────────────────────────────────────────────────────"
    printf "%-3s │ %-10s │ %-10s │ %-30s │ %s\n" "" "Severity" "Confidence" "Issue" "Location"
    echo "─────────────────────────────────────────────────────────────────"
    
    # Parse and display
    parse_burp_xml "$file" "$min_severity" | while IFS='|' read -r icon severity confidence name location; do
        # Truncate for display
        local short_name="${name:0:30}"
        local short_loc="${location:0:30}"
        printf "%-3s │ %-10s │ %-10s │ %-30s │ %s\n" "$icon" "$severity" "$confidence" "$short_name" "$short_loc"
    done
    
    echo "─────────────────────────────────────────────────────────────────"
    echo ""
}

#######################################
# Manage templates
#######################################
do_templates() {
    local subcmd="${1:-list}"
    
    case "$subcmd" in
        list)
            echo ""
            echo "📄 Available Burp Templates"
            echo ""
            echo "  default     - Standard vulnerability report"
            echo "  pentest     - Pentest finding format"
            echo "  compliance  - Compliance-focused format"
            echo "  executive   - Executive summary format"
            echo ""
            ;;
        show)
            local template="${2:-default}"
            echo "Template: $template"
            echo "TODO: Show template content"
            ;;
        create)
            echo "TODO: Create custom template"
            ;;
        *)
            log_error "Unknown template command: $subcmd"
            echo "Available: list, show, create"
            return 1
            ;;
    esac
}

#######################################
# Main entry point
#######################################
main() {
    local command=""
    local input_file=""
    local customer_id=""
    local output_dir=""
    # shellcheck disable=SC2034  # Reserved for HTML format support (future feature)
    local format="xml"
    local min_severity=""
    local keep_raw=false
    local skip_summary=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            import|parse|templates)
                command="$1"
                shift
                if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
                    input_file="$1"
                    shift
                fi
                ;;
            -c|--customer)
                customer_id="$2"
                shift 2
                ;;
            -o|--output-dir)
                output_dir="$2"
                shift 2
                ;;
            -f|--format)
                # shellcheck disable=SC2034  # Reserved for HTML format support
                format="$2"
                shift 2
                ;;
            --severity)
                min_severity="$2"
                shift 2
                ;;
            --raw)
                keep_raw=true
                shift
                ;;
            --no-summary)
                skip_summary=true
                shift
                ;;
            -q|--quiet)
                QUIET_MODE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE_MODE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                if [[ -z "$input_file" && -f "$1" ]]; then
                    input_file="$1"
                else
                    log_error "Unknown option: $1"
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Default command
    if [[ -z "$command" ]]; then
        show_usage
        exit 0
    fi
    
    # Execute command
    case "$command" in
        import)
            if [[ -z "$input_file" ]]; then
                log_error "No input file specified"
                exit 1
            fi
            if [[ -z "$customer_id" ]]; then
                log_error "Customer ID required. Use -c or --customer"
                exit 1
            fi
            do_import "$input_file" "$customer_id" "$output_dir" "$min_severity" "$keep_raw" "$skip_summary"
            ;;
        parse)
            if [[ -z "$input_file" ]]; then
                log_error "No input file specified"
                exit 1
            fi
            do_parse "$input_file" "$min_severity"
            ;;
        templates)
            do_templates "$input_file"
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
