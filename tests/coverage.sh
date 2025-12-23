#!/usr/bin/env bash
# AutoVault Code Coverage Report Generator
# Usage: ./coverage.sh [--html] [--json]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COVERAGE_DIR="$PROJECT_ROOT/coverage"
REPORT_FORMAT="text"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --html) REPORT_FORMAT="html"; shift ;;
        --json) REPORT_FORMAT="json"; shift ;;
        -h|--help)
            echo "Usage: $0 [--html] [--json]"
            echo "Generate code coverage report for AutoVault"
            exit 0
            ;;
        *) shift ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Analyze test coverage
analyze_coverage() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           AutoVault Code Coverage Analysis                   ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    mkdir -p "$COVERAGE_DIR"
    
    # Get test content
    local test_content=""
    if [[ -f "$PROJECT_ROOT/tests/run-tests.sh" ]]; then
        test_content=$(cat "$PROJECT_ROOT/tests/run-tests.sh")
    fi
    
    local total_functions=0
    local tested_functions=0
    
    # Declare associative array for file coverage
    declare -A file_coverage_map
    
    echo -e "${YELLOW}File Coverage:${NC}"
    echo "─────────────────────────────────────────────────────────────"
    printf "%-40s %8s %8s %8s\n" "File" "Funcs" "Tested" "Coverage"
    echo "─────────────────────────────────────────────────────────────"
    
    # List of scripts to analyze
    local scripts=(
        "cust-run-config.sh"
        "bash/Manage-Customers.sh"
        "bash/Manage-Templates.sh"
        "bash/Manage-Sections.sh"
        "bash/Manage-Backups.sh"
        "bash/Show-Status.sh"
        "bash/Show-Statistics.sh"
        "bash/Validate-Config.sh"
        "bash/Manage-Vaults.sh"
        "bash/Manage-Plugins.sh"
        "bash/Manage-Encryption.sh"
        "bash/lib/config.sh"
        "bash/lib/logging.sh"
        "bash/lib/hooks.sh"
        "bash/lib/remote.sh"
        "bash/lib/version.sh"
        "bash/lib/diff.sh"
        "bash/lib/help.sh"
        "bash/lib/plugins.sh"
        "bash/lib/template-vars.sh"
    )
    
    for script in "${scripts[@]}"; do
        local filepath="$PROJECT_ROOT/$script"
        [[ ! -f "$filepath" ]] && continue
        
        local file_funcs=0
        local file_tested=0
        
        # Get functions from file
        local funcs
        funcs=$(grep -E '^[a-zA-Z_][a-zA-Z0-9_-]*[[:space:]]*\(\)' "$filepath" 2>/dev/null | \
                sed 's/().*//' | sed 's/[[:space:]]*$//' | tr -d ' ' || echo "")
        
        while IFS= read -r func; do
            [[ -z "$func" ]] && continue
            ((file_funcs++)) || true
            ((total_functions++)) || true
            
            # Check if function is tested
            local script_name
            script_name=$(basename "$script" .sh)
            if echo "$test_content" | grep -qE "(${func}|${script_name})" 2>/dev/null; then
                ((file_tested++)) || true
                ((tested_functions++)) || true
            fi
        done <<< "$funcs"
        
        # Skip if no functions
        [[ $file_funcs -eq 0 ]] && continue
        
        # Calculate coverage percentage
        local coverage=$((file_tested * 100 / file_funcs))
        file_coverage_map["$script"]=$coverage
        
        # Color based on coverage
        local color=$RED
        [[ $coverage -ge 50 ]] && color=$YELLOW
        [[ $coverage -ge 80 ]] && color=$GREEN
        
        printf "%-40s %8d %8d ${color}%7d%%${NC}\n" \
            "$(basename "$script")" "$file_funcs" "$file_tested" "$coverage"
    done
    
    echo "─────────────────────────────────────────────────────────────"
    
    # Overall coverage
    local overall_coverage=0
    [[ $total_functions -gt 0 ]] && overall_coverage=$((tested_functions * 100 / total_functions))
    
    local color=$RED
    [[ $overall_coverage -ge 50 ]] && color=$YELLOW
    [[ $overall_coverage -ge 80 ]] && color=$GREEN
    
    printf "%-40s %8d %8d ${color}%7d%%${NC}\n" \
        "TOTAL" "$total_functions" "$tested_functions" "$overall_coverage"
    echo
    
    # Test statistics
    echo -e "${YELLOW}Test Statistics:${NC}"
    echo "─────────────────────────────────────────────────────────────"
    
    local test_count=0
    if [[ -f "$PROJECT_ROOT/tests/run-tests.sh" ]]; then
        test_count=$(grep -c '@test\|^test_' "$PROJECT_ROOT/tests/run-tests.sh" 2>/dev/null || echo 0)
    fi
    
    echo "  Test file:      run-tests.sh"
    echo "  Total tests:    $test_count"
    echo "  Functions:      $total_functions"
    echo "  Tested funcs:   $tested_functions"
    echo
    
    # Generate reports
    case "$REPORT_FORMAT" in
        html)
            generate_html_report "$overall_coverage" "$total_functions" "$tested_functions" "$test_count"
            ;;
        json)
            generate_json_report "$overall_coverage" "$total_functions" "$tested_functions" "$test_count"
            ;;
    esac
    
    # Summary badge
    echo -e "${YELLOW}Coverage Badge:${NC}"
    echo "─────────────────────────────────────────────────────────────"
    local badge_color="red"
    [[ $overall_coverage -ge 50 ]] && badge_color="yellow"
    [[ $overall_coverage -ge 80 ]] && badge_color="brightgreen"
    
    echo "  Shields.io URL:"
    echo "  https://img.shields.io/badge/coverage-${overall_coverage}%25-${badge_color}"
    echo
    
    # Save coverage to file for CI
    echo "$overall_coverage" > "$COVERAGE_DIR/coverage.txt"
    echo -e "${GREEN}✓${NC} Coverage saved to: $COVERAGE_DIR/coverage.txt"
    
    return 0
}

generate_html_report() {
    local coverage=$1
    local total=$2
    local tested=$3
    local tests=$4
    
    local html_file="$COVERAGE_DIR/coverage.html"
    
    local color_class="red"
    [[ $coverage -ge 50 ]] && color_class="yellow"
    [[ $coverage -ge 80 ]] && color_class="green"
    
    cat > "$html_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AutoVault Coverage Report</title>
    <style>
        * { box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', sans-serif;
            margin: 0;
            padding: 40px;
            background: #f6f8fa;
            color: #24292e;
        }
        .container { max-width: 900px; margin: 0 auto; }
        .header {
            background: linear-gradient(135deg, #24292e 0%, #586069 100%);
            color: white;
            padding: 30px;
            border-radius: 12px;
            margin-bottom: 30px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .header h1 { margin: 0 0 10px 0; font-size: 28px; }
        .header p { margin: 0; opacity: 0.8; }
        .metrics {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .metric {
            background: white;
            padding: 25px;
            border-radius: 12px;
            text-align: center;
            box-shadow: 0 2px 4px rgba(0,0,0,0.05);
        }
        .metric-value { font-size: 42px; font-weight: 700; }
        .metric-label { font-size: 14px; color: #586069; margin-top: 5px; }
        .green { color: #22c55e; }
        .yellow { color: #eab308; }
        .red { color: #ef4444; }
        .card {
            background: white;
            border-radius: 12px;
            padding: 25px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.05);
        }
        .card h2 { margin-top: 0; color: #24292e; }
        .progress-container {
            width: 100%;
            height: 24px;
            background: #e1e4e8;
            border-radius: 12px;
            overflow: hidden;
            margin-top: 20px;
        }
        .progress-bar {
            height: 100%;
            border-radius: 12px;
            transition: width 0.5s ease;
        }
        .progress-bar.green { background: linear-gradient(90deg, #22c55e, #4ade80); }
        .progress-bar.yellow { background: linear-gradient(90deg, #eab308, #facc15); }
        .progress-bar.red { background: linear-gradient(90deg, #ef4444, #f87171); }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 AutoVault Coverage Report</h1>
            <p>Generated: $(date '+%Y-%m-%d %H:%M:%S')</p>
        </div>
        
        <div class="metrics">
            <div class="metric">
                <div class="metric-value ${color_class}">${coverage}%</div>
                <div class="metric-label">Overall Coverage</div>
            </div>
            <div class="metric">
                <div class="metric-value">${tested}/${total}</div>
                <div class="metric-label">Functions Tested</div>
            </div>
            <div class="metric">
                <div class="metric-value">${tests}</div>
                <div class="metric-label">Total Tests</div>
            </div>
        </div>
        
        <div class="card">
            <h2>Coverage Progress</h2>
            <div class="progress-container">
                <div class="progress-bar ${color_class}" style="width: ${coverage}%;"></div>
            </div>
        </div>
    </div>
</body>
</html>
EOF
    
    echo -e "${GREEN}✓${NC} HTML report: $html_file"
}

generate_json_report() {
    local coverage=$1
    local total=$2
    local tested=$3
    local tests=$4
    
    local json_file="$COVERAGE_DIR/coverage.json"
    
    cat > "$json_file" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "version": "$(grep 'VERSION=' "$PROJECT_ROOT/cust-run-config.sh" 2>/dev/null | head -1 | cut -d'"' -f2 || echo "unknown")",
  "summary": {
    "overall_coverage": $coverage,
    "total_functions": $total,
    "tested_functions": $tested,
    "total_tests": $tests
  }
}
EOF
    
    echo -e "${GREEN}✓${NC} JSON report: $json_file"
}

# Run analysis
analyze_coverage
