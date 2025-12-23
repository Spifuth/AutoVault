#!/usr/bin/env bash
#===============================================================================
#
#  AUTOVAULT - Import-Nmap.sh
#
#===============================================================================
#
#  DESCRIPTION:    Import Nmap scan results into customer folders
#                  Parses XML output and generates Markdown notes
#
#  COMMANDS:       import <file> <customer>  - Import scan to customer
#                  parse <file>              - Preview parsed results
#                  templates                 - Show available templates
#
#  USAGE:          ./cust-run-config.sh nmap import scan.xml ACME
#                  ./cust-run-config.sh nmap parse scan.xml
#
#  SUPPORTED:      - Nmap XML output (-oX)
#                  - Nmap grepable output (-oG)
#                  - Multiple hosts per scan
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
# shellcheck disable=SC2034  # Configuration variables used by functions
DEFAULT_SECTION="INFORMATIONS"
DEFAULT_TEMPLATE="default"
NMAP_TEMPLATES_DIR="$SCRIPT_DIR/../config/nmap-templates"

#--------------------------------------
# CHECK DEPENDENCIES
#--------------------------------------
check_nmap_dependencies() {
    local missing=()
    
    # xmllint for XML parsing (libxml2)
    if ! command -v xmllint &>/dev/null; then
        missing+=("xmllint (libxml2-utils)")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warning "Optional dependencies missing: ${missing[*]}"
        log_info "XML parsing will use fallback method (grep/awk)"
    fi
    
    return 0
}

#--------------------------------------
# DETECT FILE FORMAT
#--------------------------------------
detect_format() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi
    
    # Check first few lines
    local head_content
    head_content=$(head -5 "$file")
    
    if echo "$head_content" | grep -q '<?xml.*nmap'; then
        echo "xml"
    elif echo "$head_content" | grep -q '^# Nmap'; then
        echo "gnmap"
    elif echo "$head_content" | grep -q 'Nmap scan report'; then
        echo "normal"
    else
        log_error "Unknown file format. Supported: XML (-oX), Grepable (-oG), Normal (-oN)"
        return 1
    fi
}

#--------------------------------------
# PARSE XML FORMAT (preferred)
#--------------------------------------
parse_xml() {
    local file="$1"
    local output=""
    
    # Check if xmllint is available
    if command -v xmllint &>/dev/null; then
        parse_xml_with_xmllint "$file"
    else
        parse_xml_with_grep "$file"
    fi
}

parse_xml_with_xmllint() {
    local file="$1"
    
    # Extract scan info
    local scan_args scan_start scan_version
    scan_args=$(xmllint --xpath "string(//nmaprun/@args)" "$file" 2>/dev/null || echo "N/A")
    scan_start=$(xmllint --xpath "string(//nmaprun/@startstr)" "$file" 2>/dev/null || echo "N/A")
    scan_version=$(xmllint --xpath "string(//nmaprun/@version)" "$file" 2>/dev/null || echo "N/A")
    
    # Get host count
    local host_count
    host_count=$(xmllint --xpath "count(//host)" "$file" 2>/dev/null || echo "0")
    
    # Output JSON-like structure for processing
    cat <<EOF
{
  "scan_info": {
    "args": "$scan_args",
    "start": "$scan_start",
    "version": "$scan_version",
    "host_count": $host_count
  },
  "hosts": [
EOF
    
    # Parse each host
    local i=1
    while [[ $i -le $host_count ]]; do
        local ip hostname state
        ip=$(xmllint --xpath "string(//host[$i]/address[@addrtype='ipv4']/@addr)" "$file" 2>/dev/null || echo "")
        [[ -z "$ip" ]] && ip=$(xmllint --xpath "string(//host[$i]/address[@addrtype='ipv6']/@addr)" "$file" 2>/dev/null || echo "unknown")
        hostname=$(xmllint --xpath "string(//host[$i]/hostnames/hostname/@name)" "$file" 2>/dev/null || echo "")
        state=$(xmllint --xpath "string(//host[$i]/status/@state)" "$file" 2>/dev/null || echo "unknown")
        
        # Get open ports
        local ports_json="["
        local port_count
        port_count=$(xmllint --xpath "count(//host[$i]/ports/port)" "$file" 2>/dev/null || echo "0")
        
        local j=1
        while [[ $j -le $port_count ]]; do
            local portid protocol service_name service_product state_port
            portid=$(xmllint --xpath "string(//host[$i]/ports/port[$j]/@portid)" "$file" 2>/dev/null || echo "")
            protocol=$(xmllint --xpath "string(//host[$i]/ports/port[$j]/@protocol)" "$file" 2>/dev/null || echo "tcp")
            state_port=$(xmllint --xpath "string(//host[$i]/ports/port[$j]/state/@state)" "$file" 2>/dev/null || echo "")
            service_name=$(xmllint --xpath "string(//host[$i]/ports/port[$j]/service/@name)" "$file" 2>/dev/null || echo "unknown")
            service_product=$(xmllint --xpath "string(//host[$i]/ports/port[$j]/service/@product)" "$file" 2>/dev/null || echo "")
            service_version=$(xmllint --xpath "string(//host[$i]/ports/port[$j]/service/@version)" "$file" 2>/dev/null || echo "")
            
            [[ $j -gt 1 ]] && ports_json+=","
            ports_json+="{\"port\":$portid,\"protocol\":\"$protocol\",\"state\":\"$state_port\",\"service\":\"$service_name\",\"product\":\"$service_product\",\"version\":\"$service_version\"}"
            
            ((j++))
        done
        ports_json+="]"
        
        # Get OS detection
        local os_name os_accuracy
        os_name=$(xmllint --xpath "string(//host[$i]/os/osmatch[1]/@name)" "$file" 2>/dev/null || echo "")
        os_accuracy=$(xmllint --xpath "string(//host[$i]/os/osmatch[1]/@accuracy)" "$file" 2>/dev/null || echo "")
        
        [[ $i -gt 1 ]] && echo ","
        cat <<EOF
    {
      "ip": "$ip",
      "hostname": "$hostname",
      "state": "$state",
      "os": "$os_name",
      "os_accuracy": "$os_accuracy",
      "ports": $ports_json
    }
EOF
        ((i++))
    done
    
    echo "  ]"
    echo "}"
}

parse_xml_with_grep() {
    local file="$1"
    
    # Fallback parser using grep/awk/sed
    log_info "Using fallback XML parser (grep/awk)"
    
    # Extract basic info
    local scan_args scan_start
    scan_args=$(grep -oP 'args="\K[^"]+' "$file" | head -1 || echo "N/A")
    scan_start=$(grep -oP 'startstr="\K[^"]+' "$file" | head -1 || echo "N/A")
    
    cat <<EOF
{
  "scan_info": {
    "args": "$scan_args",
    "start": "$scan_start",
    "version": "N/A",
    "host_count": $(grep -c '<host ' "$file" || echo "0")
  },
  "hosts": [
EOF
    
    # Simple host extraction
    local first=true
    while IFS= read -r line; do
        if echo "$line" | grep -q '<address.*addr='; then
            local ip
            ip=$(echo "$line" | grep -oP 'addr="\K[^"]+' | head -1)
            
            [[ "$first" != "true" ]] && echo ","
            first=false
            
            echo "    {\"ip\": \"$ip\", \"hostname\": \"\", \"state\": \"up\", \"ports\": []}"
        fi
    done < "$file"
    
    echo "  ]"
    echo "}"
}

#--------------------------------------
# PARSE GREPABLE FORMAT
#--------------------------------------
parse_gnmap() {
    local file="$1"
    
    cat <<EOF
{
  "scan_info": {
    "args": "$(head -1 "$file" | sed 's/^# //')",
    "start": "$(head -1 "$file" | grep -oP '\d{4}-\d{2}-\d{2} \d{2}:\d{2}' || echo 'N/A')",
    "version": "N/A",
    "host_count": $(grep -c '^Host:' "$file" || echo "0")
  },
  "hosts": [
EOF
    
    local first=true
    while IFS= read -r line; do
        if [[ "$line" =~ ^Host: ]]; then
            local ip hostname ports_str
            ip=$(echo "$line" | awk '{print $2}')
            hostname=$(echo "$line" | grep -oP '\(\K[^)]+' || echo "")
            ports_str=$(echo "$line" | grep -oP 'Ports: \K.*' || echo "")
            
            [[ "$first" != "true" ]] && echo ","
            first=false
            
            # Parse ports
            local ports_json="["
            local port_first=true
            if [[ -n "$ports_str" ]]; then
                IFS=',' read -ra port_entries <<< "$ports_str"
                for entry in "${port_entries[@]}"; do
                    entry=$(echo "$entry" | xargs)  # trim
                    local port state service
                    port=$(echo "$entry" | cut -d'/' -f1)
                    state=$(echo "$entry" | cut -d'/' -f2)
                    service=$(echo "$entry" | cut -d'/' -f5)
                    
                    [[ "$port_first" != "true" ]] && ports_json+=","
                    port_first=false
                    ports_json+="{\"port\":$port,\"protocol\":\"tcp\",\"state\":\"$state\",\"service\":\"$service\"}"
                done
            fi
            ports_json+="]"
            
            cat <<EOF
    {
      "ip": "$ip",
      "hostname": "$hostname",
      "state": "up",
      "os": "",
      "ports": $ports_json
    }
EOF
        fi
    done < "$file"
    
    echo "  ]"
    echo "}"
}

#--------------------------------------
# GENERATE MARKDOWN
#--------------------------------------
generate_markdown() {
    local json_data="$1"
    local template="${2:-default}"
    local customer_id="${3:-}"
    
    # Parse JSON with jq if available, otherwise use basic parsing
    if command -v jq &>/dev/null; then
        generate_markdown_with_jq "$json_data" "$template" "$customer_id"
    else
        generate_markdown_basic "$json_data" "$template" "$customer_id"
    fi
}

generate_markdown_with_jq() {
    local json_data="$1"
    local template="$2"
    local customer_id="$3"
    
    local scan_args scan_start host_count
    scan_args=$(echo "$json_data" | jq -r '.scan_info.args // "N/A"')
    scan_start=$(echo "$json_data" | jq -r '.scan_info.start // "N/A"')
    host_count=$(echo "$json_data" | jq -r '.scan_info.host_count // 0')
    
    cat <<EOF
# 🔍 Nmap Scan Results

## Scan Information

| Property | Value |
|----------|-------|
| **Date** | $scan_start |
| **Command** | \`$scan_args\` |
| **Hosts Found** | $host_count |
| **Customer** | ${customer_id:-N/A} |
| **Imported** | $(date '+%Y-%m-%d %H:%M:%S') |

---

## Hosts Summary

EOF
    
    # Generate hosts table
    echo "| IP Address | Hostname | State | Open Ports |"
    echo "|------------|----------|-------|------------|"
    
    echo "$json_data" | jq -r '.hosts[] | "| \(.ip) | \(.hostname // "-") | \(.state) | \(.ports | map(select(.state == "open")) | length) |"'
    
    echo ""
    echo "---"
    echo ""
    
    # Detailed host information
    echo "## Detailed Results"
    echo ""
    
    local host_index=0
    echo "$json_data" | jq -c '.hosts[]' | while read -r host; do
        ((host_index++))
        
        local ip hostname state os
        ip=$(echo "$host" | jq -r '.ip')
        hostname=$(echo "$host" | jq -r '.hostname // ""')
        state=$(echo "$host" | jq -r '.state')
        os=$(echo "$host" | jq -r '.os // ""')
        
        echo "### Host $host_index: $ip"
        [[ -n "$hostname" ]] && echo "**Hostname:** $hostname"
        echo "**State:** $state"
        [[ -n "$os" ]] && echo "**OS Detection:** $os"
        echo ""
        
        # Ports table
        local port_count
        port_count=$(echo "$host" | jq '.ports | length')
        
        if [[ $port_count -gt 0 ]]; then
            echo "#### Open Ports"
            echo ""
            echo "| Port | Protocol | State | Service | Product | Version |"
            echo "|------|----------|-------|---------|---------|---------|"
            
            echo "$host" | jq -r '.ports[] | "| \(.port) | \(.protocol // "tcp") | \(.state) | \(.service // "-") | \(.product // "-") | \(.version // "-") |"'
            echo ""
        else
            echo "*No open ports detected*"
            echo ""
        fi
        
        echo "---"
        echo ""
    done
    
    # Footer
    cat <<EOF

## Notes

> Add your analysis notes here...

## Tags

\`#nmap\` \`#scan\` \`#reconnaissance\`
EOF
}

generate_markdown_basic() {
    local json_data="$1"
    local template="$2"
    local customer_id="$3"
    
    # Basic markdown generation without jq
    cat <<EOF
# 🔍 Nmap Scan Results

## Scan Information

- **Customer:** ${customer_id:-N/A}
- **Imported:** $(date '+%Y-%m-%d %H:%M:%S')

---

## Raw Data

\`\`\`json
$json_data
\`\`\`

---

## Notes

> Add your analysis notes here...

## Tags

\`#nmap\` \`#scan\` \`#reconnaissance\`
EOF
}

#--------------------------------------
# IMPORT TO CUSTOMER
#--------------------------------------
import_to_customer() {
    local file="$1"
    local customer_id="$2"
    local section="${3:-$DEFAULT_SECTION}"
    local template="${4:-$DEFAULT_TEMPLATE}"
    
    # Validate customer exists
    local vault_root
    vault_root=$(get_vault_path)
    
    if [[ -z "$vault_root" ]]; then
        log_error "No vault configured. Run 'autovault config' first."
        return 1
    fi
    
    # Find customer folder
    local customer_dir
    customer_dir=$(find "$vault_root" -maxdepth 2 -type d -name "*${customer_id}*" | head -1)
    
    if [[ -z "$customer_dir" || ! -d "$customer_dir" ]]; then
        log_error "Customer not found: $customer_id"
        log_info "Available customers:"
        find "$vault_root" -maxdepth 2 -type d -name "CUST-*" -o -name "*-*" 2>/dev/null | head -10
        return 1
    fi
    
    # Find or create section folder
    local section_dir="$customer_dir/$customer_id-$section"
    if [[ ! -d "$section_dir" ]]; then
        section_dir=$(find "$customer_dir" -maxdepth 1 -type d -name "*$section*" | head -1)
    fi
    
    if [[ -z "$section_dir" || ! -d "$section_dir" ]]; then
        log_warning "Section '$section' not found, creating..."
        section_dir="$customer_dir/$customer_id-$section"
        mkdir -p "$section_dir"
    fi
    
    log_info "Importing scan to: $section_dir"
    
    # Detect format and parse
    local format
    format=$(detect_format "$file") || return 1
    log_info "Detected format: $format"
    
    local json_data
    case "$format" in
        xml)
            json_data=$(parse_xml "$file")
            ;;
        gnmap)
            json_data=$(parse_gnmap "$file")
            ;;
        *)
            log_error "Unsupported format: $format"
            return 1
            ;;
    esac
    
    # Generate markdown
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local output_file="$section_dir/nmap_scan_${timestamp}.md"
    
    generate_markdown "$json_data" "$template" "$customer_id" > "$output_file"
    
    log_success "Scan imported to: $output_file"
    
    # Also save raw XML/data
    local raw_file="$section_dir/nmap_scan_${timestamp}_raw.${format}"
    cp "$file" "$raw_file"
    log_info "Raw data saved to: $raw_file"
    
    echo ""
    echo "Files created:"
    echo "  📄 $output_file"
    echo "  📦 $raw_file"
}

#--------------------------------------
# PREVIEW PARSE
#--------------------------------------
preview_parse() {
    local file="$1"
    local format
    
    format=$(detect_format "$file") || return 1
    log_info "Format detected: $format"
    echo ""
    
    local json_data
    case "$format" in
        xml)
            json_data=$(parse_xml "$file")
            ;;
        gnmap)
            json_data=$(parse_gnmap "$file")
            ;;
        *)
            log_error "Unsupported format"
            return 1
            ;;
    esac
    
    echo "=== Parsed Data ==="
    echo ""
    
    if command -v jq &>/dev/null; then
        echo "$json_data" | jq .
    else
        echo "$json_data"
    fi
    
    echo ""
    echo "=== Preview Markdown ==="
    echo ""
    generate_markdown "$json_data" "default" ""
}

#--------------------------------------
# SHOW TEMPLATES
#--------------------------------------
show_templates() {
    echo ""
    echo "Available Nmap Import Templates:"
    echo ""
    echo "  default     - Standard format with all details"
    echo "  minimal     - Basic host/port list"
    echo "  pentest     - Pentest report format"
    echo "  inventory   - Asset inventory format"
    echo ""
    echo "Use with: autovault nmap import <file> <customer> --template <name>"
}

#--------------------------------------
# HELP
#--------------------------------------
show_help() {
    cat <<'EOF'
AutoVault Nmap Import - Import scan results into customer folders

USAGE:
    autovault nmap <command> [options]

COMMANDS:
    import <file> <customer>   Import scan to customer folder
    parse <file>               Preview parsed results
    templates                  Show available templates

OPTIONS:
    -s, --section <name>       Target section (default: INFORMATIONS)
    -t, --template <name>      Output template (default: default)
    --help, -h                 Show this help

SUPPORTED FORMATS:
    - Nmap XML output (-oX scan.xml)
    - Nmap grepable output (-oG scan.gnmap)

EXAMPLES:
    # Import XML scan to customer ACME
    autovault nmap import scan.xml ACME

    # Import to specific section
    autovault nmap import scan.xml ACME -s RAISED

    # Preview what would be parsed
    autovault nmap parse scan.xml

    # Use pentest template
    autovault nmap import scan.xml ACME -t pentest

WORKFLOW:
    1. Run your nmap scan:
       nmap -sV -oX scan.xml target.com

    2. Import to customer:
       autovault nmap import scan.xml ACME

    3. Find results in:
       Vault/Run/ACME/ACME-INFORMATIONS/nmap_scan_*.md

EOF
}

#--------------------------------------
# MAIN
#--------------------------------------
main() {
    local command="${1:-}"
    shift || true
    
    check_nmap_dependencies
    
    case "$command" in
        import)
            local file="" customer="" section="$DEFAULT_SECTION" template="$DEFAULT_TEMPLATE"
            
            # Parse arguments
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    -s|--section)
                        section="$2"
                        shift 2
                        ;;
                    -t|--template)
                        template="$2"
                        shift 2
                        ;;
                    --help|-h)
                        show_help
                        return 0
                        ;;
                    *)
                        if [[ -z "$file" ]]; then
                            file="$1"
                        elif [[ -z "$customer" ]]; then
                            customer="$1"
                        fi
                        shift
                        ;;
                esac
            done
            
            if [[ -z "$file" || -z "$customer" ]]; then
                log_error "Usage: autovault nmap import <file> <customer>"
                return 1
            fi
            
            import_to_customer "$file" "$customer" "$section" "$template"
            ;;
        
        parse|preview)
            local file="${1:-}"
            if [[ -z "$file" ]]; then
                log_error "Usage: autovault nmap parse <file>"
                return 1
            fi
            preview_parse "$file"
            ;;
        
        templates)
            show_templates
            ;;
        
        help|--help|-h)
            show_help
            ;;
        
        *)
            if [[ -n "$command" ]]; then
                log_error "Unknown command: $command"
            fi
            show_help
            return 1
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
