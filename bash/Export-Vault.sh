#!/usr/bin/env bash
#===============================================================================
#
#  AUTOVAULT - Export-Vault.sh
#
#===============================================================================
#
#  DESCRIPTION:    Export vault content to various formats (PDF, HTML, Markdown)
#                  Supports single customer, multiple customers, or full vault
#
#  COMMANDS:       pdf <target>     - Export to PDF
#                  html <target>    - Export to static HTML
#                  markdown <target> - Export compiled Markdown
#                  report <id>      - Generate professional client report
#
#  USAGE:          ./cust-run-config.sh export pdf customer 42
#                  ./cust-run-config.sh export html vault
#                  ./cust-run-config.sh export report 42 --template pentest
#
#  DEPENDENCIES:   pandoc (PDF/HTML), wkhtmltopdf (optional), weasyprint (optional)
#
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/config.sh"

#--------------------------------------
# CONFIGURATION
#--------------------------------------
EXPORT_DIR=""
OUTPUT_FORMAT=""
TEMPLATE_NAME="default"
INCLUDE_TOC=true
INCLUDE_METADATA=true
CUSTOM_CSS=""
PAGE_SIZE="A4"
VERBOSE=false

#--------------------------------------
# CHECK DEPENDENCIES
#--------------------------------------
check_export_dependencies() {
    local format="${1:-pdf}"
    local missing=()
    
    case "$format" in
        pdf)
            if ! command -v pandoc &>/dev/null; then
                missing+=("pandoc")
            fi
            # Check for PDF engine
            if ! command -v wkhtmltopdf &>/dev/null && \
               ! command -v weasyprint &>/dev/null && \
               ! command -v pdflatex &>/dev/null; then
                log_warning "No PDF engine found. Install one of: wkhtmltopdf, weasyprint, or texlive"
            fi
            ;;
        html)
            if ! command -v pandoc &>/dev/null; then
                missing+=("pandoc")
            fi
            ;;
        markdown)
            # No special dependencies for markdown compilation
            ;;
    esac
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing[*]}"
        echo
        echo "Install with:"
        if [[ -f /etc/debian_version ]]; then
            echo "  sudo apt-get install ${missing[*]}"
        elif [[ -f /etc/arch-release ]]; then
            echo "  sudo pacman -S ${missing[*]}"
        elif [[ "$(uname)" == "Darwin" ]]; then
            echo "  brew install ${missing[*]}"
        fi
        return 1
    fi
    
    return 0
}

#--------------------------------------
# GET PDF ENGINE
#--------------------------------------
get_pdf_engine() {
    if command -v wkhtmltopdf &>/dev/null; then
        echo "wkhtmltopdf"
    elif command -v weasyprint &>/dev/null; then
        echo "weasyprint"
    elif command -v pdflatex &>/dev/null; then
        echo "pdflatex"
    else
        echo "html"  # Fallback to HTML
    fi
}

#--------------------------------------
# GENERATE CSS STYLES
#--------------------------------------
generate_css() {
    cat << 'CSS'
/* AutoVault Export Styles */
:root {
    --primary-color: #2563eb;
    --secondary-color: #64748b;
    --background: #ffffff;
    --text-color: #1e293b;
    --border-color: #e2e8f0;
    --code-bg: #f1f5f9;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
    font-size: 11pt;
    line-height: 1.6;
    color: var(--text-color);
    max-width: 210mm;
    margin: 0 auto;
    padding: 20mm;
}

h1 {
    color: var(--primary-color);
    border-bottom: 3px solid var(--primary-color);
    padding-bottom: 10px;
    margin-top: 30px;
}

h2 {
    color: var(--primary-color);
    border-bottom: 1px solid var(--border-color);
    padding-bottom: 8px;
    margin-top: 25px;
}

h3 { color: var(--secondary-color); margin-top: 20px; }
h4 { color: var(--secondary-color); }

code {
    background: var(--code-bg);
    padding: 2px 6px;
    border-radius: 4px;
    font-family: 'JetBrains Mono', 'Fira Code', Consolas, monospace;
    font-size: 0.9em;
}

pre {
    background: var(--code-bg);
    padding: 15px;
    border-radius: 8px;
    overflow-x: auto;
    border: 1px solid var(--border-color);
}

pre code {
    background: none;
    padding: 0;
}

table {
    width: 100%;
    border-collapse: collapse;
    margin: 20px 0;
}

th, td {
    border: 1px solid var(--border-color);
    padding: 10px 12px;
    text-align: left;
}

th {
    background: var(--primary-color);
    color: white;
    font-weight: 600;
}

tr:nth-child(even) { background: #f8fafc; }
tr:hover { background: #f1f5f9; }

blockquote {
    border-left: 4px solid var(--primary-color);
    margin: 20px 0;
    padding: 10px 20px;
    background: #f8fafc;
    color: var(--secondary-color);
}

a {
    color: var(--primary-color);
    text-decoration: none;
}

a:hover { text-decoration: underline; }

.toc {
    background: #f8fafc;
    padding: 20px;
    border-radius: 8px;
    margin-bottom: 30px;
}

.toc h2 {
    margin-top: 0;
    border: none;
}

.metadata {
    background: #f1f5f9;
    padding: 15px 20px;
    border-radius: 8px;
    margin-bottom: 30px;
    font-size: 0.9em;
}

.metadata dt { font-weight: 600; color: var(--secondary-color); }
.metadata dd { margin-left: 0; margin-bottom: 8px; }

.page-break { page-break-after: always; }

.header {
    text-align: center;
    margin-bottom: 40px;
    padding-bottom: 20px;
    border-bottom: 2px solid var(--primary-color);
}

.header h1 {
    border: none;
    margin: 0;
    font-size: 2em;
}

.header .subtitle {
    color: var(--secondary-color);
    font-size: 1.2em;
    margin-top: 10px;
}

.footer {
    text-align: center;
    color: var(--secondary-color);
    font-size: 0.8em;
    margin-top: 40px;
    padding-top: 20px;
    border-top: 1px solid var(--border-color);
}

/* Severity colors for findings */
.critical { color: #dc2626; font-weight: bold; }
.high { color: #ea580c; font-weight: bold; }
.medium { color: #ca8a04; }
.low { color: #16a34a; }
.info { color: #2563eb; }

/* Print styles */
@media print {
    body { padding: 15mm; }
    .no-print { display: none; }
    a { color: var(--text-color); }
}
CSS
}

#--------------------------------------
# COLLECT MARKDOWN FILES
#--------------------------------------
collect_markdown_files() {
    local target="$1"
    local target_type="$2"
    local vault_path
    vault_path=$(get_vault_path)
    
    local files=()
    
    case "$target_type" in
        customer)
            local customer_dir="$vault_path/Run/CUST-${target}"
            if [[ ! -d "$customer_dir" ]]; then
                log_error "Customer CUST-${target} not found"
                return 1
            fi
            # Collect all markdown files for this customer
            while IFS= read -r -d '' file; do
                files+=("$file")
            done < <(find "$customer_dir" -name "*.md" -type f -print0 | sort -z)
            ;;
        section)
            # Format: customer_id:section_name
            local cust_id="${target%%:*}"
            local section="${target##*:}"
            local section_dir="$vault_path/Run/CUST-${cust_id}/CUST-${cust_id}-${section}"
            if [[ ! -d "$section_dir" ]]; then
                log_error "Section not found: $section_dir"
                return 1
            fi
            while IFS= read -r -d '' file; do
                files+=("$file")
            done < <(find "$section_dir" -name "*.md" -type f -print0 | sort -z)
            ;;
        vault)
            # Export entire vault
            while IFS= read -r -d '' file; do
                files+=("$file")
            done < <(find "$vault_path/Run" -name "*.md" -type f -print0 | sort -z)
            ;;
        file)
            # Single file
            if [[ -f "$target" ]]; then
                files+=("$target")
            else
                log_error "File not found: $target"
                return 1
            fi
            ;;
    esac
    
    if [[ ${#files[@]} -eq 0 ]]; then
        log_error "No markdown files found"
        return 1
    fi
    
    printf '%s\n' "${files[@]}"
}

#--------------------------------------
# COMPILE MARKDOWN
#--------------------------------------
compile_markdown() {
    local -a files=("$@")
    local compiled=""
    
    for file in "${files[@]}"; do
        local filename
        filename=$(basename "$file")
        local relative_path
        relative_path=$(realpath --relative-to="$(get_vault_path)" "$file" 2>/dev/null || echo "$file")
        
        # Add file header
        compiled+="<!-- Source: $relative_path -->"$'\n'
        
        # Read and process content
        local content
        content=$(cat "$file")
        
        # Remove Obsidian-specific syntax
        # Remove dataview blocks
        content=$(echo "$content" | sed '/^```dataview/,/^```/d')
        # Convert wiki links to standard markdown
        content=$(echo "$content" | sed 's/\[\[\([^]|]*\)|\([^]]*\)\]\]/[\2](\1)/g')
        content=$(echo "$content" | sed 's/\[\[\([^]]*\)\]\]/[\1](\1)/g')
        
        compiled+="$content"$'\n\n'
        compiled+="---"$'\n\n'
    done
    
    echo "$compiled"
}

#--------------------------------------
# GENERATE METADATA
#--------------------------------------
generate_metadata() {
    local target="$1"
    local target_type="$2"
    
    cat << EOF
---
title: "AutoVault Export"
subtitle: "${target_type^}: ${target}"
date: $(date '+%Y-%m-%d')
author: "$(whoami)"
generator: "AutoVault Export"
---

EOF
}

#--------------------------------------
# EXPORT TO PDF
#--------------------------------------
export_pdf() {
    local target="$1"
    local target_type="$2"
    local output_file="$3"
    
    check_export_dependencies pdf || return 1
    
    log_info "Collecting markdown files..."
    local files
    files=$(collect_markdown_files "$target" "$target_type") || return 1
    
    local -a file_array
    mapfile -t file_array <<< "$files"
    
    log_info "Found ${#file_array[@]} files to export"
    
    # Create temp directory
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap "rm -rf $tmp_dir" EXIT
    
    # Generate CSS
    generate_css > "$tmp_dir/style.css"
    
    # Compile markdown
    log_info "Compiling markdown..."
    local compiled
    compiled=$(compile_markdown "${file_array[@]}")
    
    # Add metadata
    if [[ "$INCLUDE_METADATA" == "true" ]]; then
        compiled="$(generate_metadata "$target" "$target_type")$compiled"
    fi
    
    echo "$compiled" > "$tmp_dir/content.md"
    
    # Get PDF engine
    local pdf_engine
    pdf_engine=$(get_pdf_engine)
    
    log_info "Generating PDF with $pdf_engine..."
    
    local pandoc_opts=(
        --from markdown
        --to pdf
        --css "$tmp_dir/style.css"
        --pdf-engine="$pdf_engine"
        --variable papersize="$PAGE_SIZE"
        --variable margin-top=20mm
        --variable margin-bottom=20mm
        --variable margin-left=20mm
        --variable margin-right=20mm
        --highlight-style tango
        --output "$output_file"
    )
    
    if [[ "$INCLUDE_TOC" == "true" ]]; then
        pandoc_opts+=(--toc --toc-depth=3)
    fi
    
    if [[ "$pdf_engine" == "html" ]]; then
        # Fallback: generate HTML first
        pandoc "${pandoc_opts[@]}" --to html "$tmp_dir/content.md" -o "${output_file%.pdf}.html"
        log_warning "PDF engine not available, generated HTML instead: ${output_file%.pdf}.html"
        return 0
    fi
    
    if pandoc "${pandoc_opts[@]}" "$tmp_dir/content.md" 2>/dev/null; then
        log_success "PDF exported to: $output_file"
    else
        # Fallback to HTML
        log_warning "PDF generation failed, falling back to HTML..."
        export_html "$target" "$target_type" "${output_file%.pdf}.html"
    fi
}

#--------------------------------------
# EXPORT TO HTML
#--------------------------------------
export_html() {
    local target="$1"
    local target_type="$2"
    local output_file="$3"
    
    check_export_dependencies html || return 1
    
    log_info "Collecting markdown files..."
    local files
    files=$(collect_markdown_files "$target" "$target_type") || return 1
    
    local -a file_array
    mapfile -t file_array <<< "$files"
    
    log_info "Found ${#file_array[@]} files to export"
    
    # Create temp directory
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap "rm -rf $tmp_dir" EXIT
    
    # Generate CSS
    generate_css > "$tmp_dir/style.css"
    
    # Compile markdown
    log_info "Compiling markdown..."
    local compiled
    compiled=$(compile_markdown "${file_array[@]}")
    
    # Add metadata
    if [[ "$INCLUDE_METADATA" == "true" ]]; then
        compiled="$(generate_metadata "$target" "$target_type")$compiled"
    fi
    
    echo "$compiled" > "$tmp_dir/content.md"
    
    log_info "Generating HTML..."
    
    local pandoc_opts=(
        --from markdown
        --to html5
        --standalone
        --css "$tmp_dir/style.css"
        --highlight-style tango
        --metadata title="AutoVault Export - ${target}"
        --output "$output_file"
    )
    
    if [[ "$INCLUDE_TOC" == "true" ]]; then
        pandoc_opts+=(--toc --toc-depth=3)
    fi
    
    # Embed CSS if single file output
    local css_content
    css_content=$(cat "$tmp_dir/style.css")
    
    if pandoc "${pandoc_opts[@]}" "$tmp_dir/content.md"; then
        # Embed CSS inline
        sed -i "s|<link rel=\"stylesheet\" href=\"$tmp_dir/style.css\" />|<style>$css_content</style>|" "$output_file" 2>/dev/null || true
        log_success "HTML exported to: $output_file"
    else
        log_error "HTML generation failed"
        return 1
    fi
}

#--------------------------------------
# EXPORT COMPILED MARKDOWN
#--------------------------------------
export_markdown() {
    local target="$1"
    local target_type="$2"
    local output_file="$3"
    
    log_info "Collecting markdown files..."
    local files
    files=$(collect_markdown_files "$target" "$target_type") || return 1
    
    local -a file_array
    mapfile -t file_array <<< "$files"
    
    log_info "Found ${#file_array[@]} files to export"
    
    # Compile markdown
    log_info "Compiling markdown..."
    local compiled
    compiled=$(compile_markdown "${file_array[@]}")
    
    # Add metadata header
    if [[ "$INCLUDE_METADATA" == "true" ]]; then
        compiled="$(generate_metadata "$target" "$target_type")$compiled"
    fi
    
    echo "$compiled" > "$output_file"
    log_success "Markdown exported to: $output_file"
}

#--------------------------------------
# GENERATE CLIENT REPORT
#--------------------------------------
generate_report() {
    local customer_id="$1"
    local output_file="$2"
    local template="${TEMPLATE_NAME:-default}"
    
    local vault_path
    vault_path=$(get_vault_path)
    local customer_dir="$vault_path/Run/CUST-${customer_id}"
    
    if [[ ! -d "$customer_dir" ]]; then
        log_error "Customer CUST-${customer_id} not found"
        return 1
    fi
    
    log_info "Generating report for CUST-${customer_id} using template: $template"
    
    # Create temp directory
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap "rm -rf $tmp_dir" EXIT
    
    # Generate report content based on template
    local report_content=""
    
    case "$template" in
        pentest)
            report_content=$(generate_pentest_report "$customer_id" "$customer_dir")
            ;;
        audit)
            report_content=$(generate_audit_report "$customer_id" "$customer_dir")
            ;;
        summary)
            report_content=$(generate_summary_report "$customer_id" "$customer_dir")
            ;;
        *)
            report_content=$(generate_default_report "$customer_id" "$customer_dir")
            ;;
    esac
    
    echo "$report_content" > "$tmp_dir/report.md"
    
    # Export to PDF
    generate_css > "$tmp_dir/style.css"
    
    local pdf_engine
    pdf_engine=$(get_pdf_engine)
    
    if [[ "$pdf_engine" != "html" ]] && command -v pandoc &>/dev/null; then
        pandoc \
            --from markdown \
            --to pdf \
            --css "$tmp_dir/style.css" \
            --pdf-engine="$pdf_engine" \
            --variable papersize="$PAGE_SIZE" \
            --toc --toc-depth=2 \
            --highlight-style tango \
            --output "$output_file" \
            "$tmp_dir/report.md" 2>/dev/null && \
        log_success "Report generated: $output_file" || {
            # Fallback to HTML
            output_file="${output_file%.pdf}.html"
            pandoc \
                --from markdown \
                --to html5 \
                --standalone \
                --css "$tmp_dir/style.css" \
                --toc \
                --output "$output_file" \
                "$tmp_dir/report.md"
            log_success "Report generated (HTML): $output_file"
        }
    else
        # No PDF support, output markdown
        cp "$tmp_dir/report.md" "$output_file"
        log_success "Report generated (Markdown): $output_file"
    fi
}

#--------------------------------------
# REPORT TEMPLATES
#--------------------------------------
generate_default_report() {
    local customer_id="$1"
    local customer_dir="$2"
    
    cat << EOF
---
title: "Client Report"
subtitle: "CUST-${customer_id}"
date: $(date '+%Y-%m-%d')
author: "$(whoami)"
---

# Executive Summary

This report provides an overview of activities and findings for client CUST-${customer_id}.

# Table of Contents

# Documentation Overview

$(find "$customer_dir" -name "*.md" -type f | while read -r file; do
    local basename
    basename=$(basename "$file" .md)
    echo "- $basename"
done)

# Detailed Content

$(compile_markdown $(find "$customer_dir" -name "*.md" -type f | head -20))

---

*Report generated by AutoVault on $(date)*
EOF
}

generate_pentest_report() {
    local customer_id="$1"
    local customer_dir="$2"
    
    cat << EOF
---
title: "Penetration Test Report"
subtitle: "CUST-${customer_id}"
date: $(date '+%Y-%m-%d')
author: "$(whoami)"
classification: "CONFIDENTIAL"
---

<div class="header">
<h1>Penetration Test Report</h1>
<p class="subtitle">CUST-${customer_id}</p>
<p>Date: $(date '+%B %d, %Y')</p>
</div>

# 1. Executive Summary

This document presents the findings from the penetration test conducted for CUST-${customer_id}.

## 1.1 Scope

<!-- Add scope details -->

## 1.2 Key Findings Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| Low | 0 |

# 2. Methodology

The assessment followed industry-standard methodologies including:
- OWASP Testing Guide
- PTES (Penetration Testing Execution Standard)
- NIST SP 800-115

# 3. Findings

$(if [[ -d "$customer_dir/CUST-${customer_id}-RAISED" ]]; then
    echo "## Identified Issues"
    echo
    compile_markdown $(find "$customer_dir/CUST-${customer_id}-RAISED" -name "*.md" -type f 2>/dev/null | head -10)
fi)

# 4. Recommendations

Based on the findings, we recommend the following remediation actions:

1. Address all critical and high severity findings immediately
2. Implement a remediation timeline for medium severity issues
3. Consider addressing low severity findings during regular maintenance

# 5. Appendices

## A. Tools Used

- Nmap
- Burp Suite
- Custom scripts

## B. References

- OWASP Top 10
- CWE/SANS Top 25

---

<div class="footer">
<p>CONFIDENTIAL - For authorized recipients only</p>
<p>Generated by AutoVault on $(date)</p>
</div>
EOF
}

generate_audit_report() {
    local customer_id="$1"
    local customer_dir="$2"
    
    cat << EOF
---
title: "Security Audit Report"
subtitle: "CUST-${customer_id}"
date: $(date '+%Y-%m-%d')
---

# Security Audit Report

**Client:** CUST-${customer_id}  
**Date:** $(date '+%Y-%m-%d')  
**Auditor:** $(whoami)

## 1. Audit Scope

<!-- Define scope -->

## 2. Compliance Status

| Control Area | Status | Notes |
|--------------|--------|-------|
| Access Control | ⬜ | |
| Data Protection | ⬜ | |
| Network Security | ⬜ | |
| Monitoring | ⬜ | |

## 3. Findings

$(compile_markdown $(find "$customer_dir" -name "*.md" -type f | head -10))

## 4. Recommendations

<!-- Add recommendations -->

---

*Report generated by AutoVault*
EOF
}

generate_summary_report() {
    local customer_id="$1"
    local customer_dir="$2"
    
    local file_count
    file_count=$(find "$customer_dir" -name "*.md" -type f | wc -l)
    
    local sections
    sections=$(find "$customer_dir" -maxdepth 1 -type d | tail -n +2 | wc -l)
    
    cat << EOF
---
title: "Summary Report"
subtitle: "CUST-${customer_id}"
date: $(date '+%Y-%m-%d')
---

# Summary Report: CUST-${customer_id}

## Overview

| Metric | Value |
|--------|-------|
| Total Files | $file_count |
| Sections | $sections |
| Last Updated | $(date '+%Y-%m-%d') |

## Sections

$(find "$customer_dir" -maxdepth 1 -type d | tail -n +2 | while read -r dir; do
    local section_name
    section_name=$(basename "$dir")
    local section_files
    section_files=$(find "$dir" -name "*.md" -type f | wc -l)
    echo "- **$section_name**: $section_files files"
done)

## Recent Activity

$(find "$customer_dir" -name "*.md" -type f -mtime -7 | head -10 | while read -r file; do
    echo "- $(basename "$file")"
done)

---

*Generated by AutoVault on $(date)*
EOF
}

#--------------------------------------
# SHOW HELP
#--------------------------------------
show_help() {
    cat << 'EOF'
AutoVault Export - Export vault content to various formats

USAGE:
    autovault export <format> <target-type> <target> [OPTIONS]

FORMATS:
    pdf         Export to PDF document
    html        Export to standalone HTML
    markdown    Export compiled Markdown
    report      Generate professional report

TARGET TYPES:
    customer <id>       Export single customer
    section <id:name>   Export specific section
    vault               Export entire vault
    file <path>         Export single file

OPTIONS:
    -o, --output <file>     Output file path
    -t, --template <name>   Report template (default, pentest, audit, summary)
    --no-toc                Disable table of contents
    --no-metadata           Disable metadata header
    --page-size <size>      Page size for PDF (A4, Letter, etc.)
    --css <file>            Custom CSS file
    -v, --verbose           Verbose output
    -h, --help              Show this help

EXAMPLES:
    # Export customer to PDF
    autovault export pdf customer 42 -o report.pdf

    # Export vault to HTML
    autovault export html vault -o vault.html

    # Generate pentest report
    autovault export report 42 --template pentest -o pentest-report.pdf

    # Export section to markdown
    autovault export markdown section 42:RAISED -o findings.md

TEMPLATES:
    default     Basic report with all content
    pentest     Penetration test report format
    audit       Security audit format
    summary     Brief summary with statistics

DEPENDENCIES:
    - pandoc (required for PDF/HTML)
    - wkhtmltopdf, weasyprint, or texlive (for PDF)
EOF
}

#--------------------------------------
# MAIN
#--------------------------------------
main() {
    local format=""
    local target_type=""
    local target=""
    local output_file=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            pdf|html|markdown|report)
                format="$1"
                shift
                ;;
            customer|section|vault|file)
                target_type="$1"
                shift
                if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
                    target="$1"
                    shift
                fi
                ;;
            -o|--output)
                output_file="$2"
                shift 2
                ;;
            -t|--template)
                TEMPLATE_NAME="$2"
                shift 2
                ;;
            --no-toc)
                INCLUDE_TOC=false
                shift
                ;;
            --no-metadata)
                INCLUDE_METADATA=false
                shift
                ;;
            --page-size)
                PAGE_SIZE="$2"
                shift 2
                ;;
            --css)
                CUSTOM_CSS="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                # Try to auto-detect target
                if [[ -z "$target" ]]; then
                    target="$1"
                fi
                shift
                ;;
        esac
    done
    
    # Validate arguments
    if [[ -z "$format" ]]; then
        log_error "No format specified"
        echo "Usage: autovault export <pdf|html|markdown|report> ..."
        exit 1
    fi
    
    # Default target type
    if [[ -z "$target_type" ]]; then
        if [[ "$format" == "report" ]]; then
            target_type="customer"
        else
            target_type="vault"
        fi
    fi
    
    # Generate default output filename
    if [[ -z "$output_file" ]]; then
        local timestamp
        timestamp=$(date '+%Y%m%d_%H%M%S')
        case "$format" in
            pdf|report)
                output_file="autovault_export_${timestamp}.pdf"
                ;;
            html)
                output_file="autovault_export_${timestamp}.html"
                ;;
            markdown)
                output_file="autovault_export_${timestamp}.md"
                ;;
        esac
    fi
    
    # Create output directory if needed
    local output_dir
    output_dir=$(dirname "$output_file")
    [[ "$output_dir" != "." ]] && mkdir -p "$output_dir"
    
    # Execute export
    case "$format" in
        pdf)
            export_pdf "$target" "$target_type" "$output_file"
            ;;
        html)
            export_html "$target" "$target_type" "$output_file"
            ;;
        markdown)
            export_markdown "$target" "$target_type" "$output_file"
            ;;
        report)
            if [[ -z "$target" ]]; then
                log_error "Customer ID required for report generation"
                exit 1
            fi
            generate_report "$target" "$output_file"
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
