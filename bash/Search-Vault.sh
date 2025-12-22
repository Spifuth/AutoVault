#!/usr/bin/env bash
#===============================================================================
#
#  SCRIPT NAME:    Search-Vault.sh
#  DESCRIPTION:    Search across all customers and notes in the vault
#                  Supports regex, case-insensitive, and file type filtering
#
#  USAGE:          ./Search-Vault.sh <query> [options]
#
#  OPTIONS:        --customer <id>    Search only in specific customer
#                  --section <name>   Search only in specific section
#                  --type <ext>       Filter by file extension (md, txt, etc.)
#                  --regex            Treat query as regex
#                  --case-sensitive   Enable case-sensitive search
#                  --names-only       Show only matching filenames
#                  --context <n>      Show n lines of context (default: 2)
#                  --json             Output as JSON
#
#  AUTHOR:         AutoVault Project
#  VERSION:        2.3.0
#
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/config.sh"

#--------------------------------------
# CONFIGURATION
#--------------------------------------
QUERY=""
CUSTOMER=""
SECTION=""
FILE_TYPE="md"
USE_REGEX=false
CASE_SENSITIVE=false
NAMES_ONLY=false
CONTEXT_LINES=2
JSON_OUTPUT=false
MAX_RESULTS=100

# Results tracking
MATCH_COUNT=0
FILE_COUNT=0
declare -a JSON_RESULTS=()

#--------------------------------------
# USAGE
#--------------------------------------
usage() {
  cat << EOF
${BOLD}USAGE${NC}
    $(basename "$0") <query> [OPTIONS]

${BOLD}DESCRIPTION${NC}
    Search across all customers and notes in your AutoVault.
    By default, searches in markdown files (.md) with case-insensitive matching.

${BOLD}ARGUMENTS${NC}
    <query>              The text or pattern to search for

${BOLD}OPTIONS${NC}
    -c, --customer <id>      Search only in specific customer
    -s, --section <name>     Search only in specific section
    -t, --type <ext>         Filter by file extension (default: md)
                             Use 'all' to search all file types
    -r, --regex              Treat query as regular expression
    -i, --case-sensitive     Enable case-sensitive search
    -n, --names-only         Show only matching filenames
    -C, --context <n>        Lines of context to show (default: 2)
    -m, --max <n>            Maximum results to show (default: 100)
    --json                   Output results as JSON
    -h, --help               Show this help message

${BOLD}EXAMPLES${NC}
    # Search for "password" in all notes
    $(basename "$0") password

    # Search in specific customer
    $(basename "$0") "SQL injection" --customer ACME

    # Search with regex
    $(basename "$0") "CVE-[0-9]{4}-[0-9]+" --regex

    # Search only filenames
    $(basename "$0") report --names-only

    # Search in reconnaissance section
    $(basename "$0") nmap --section Recon

    # Case-sensitive search with more context
    $(basename "$0") TODO --case-sensitive --context 5

EOF
}

#--------------------------------------
# PARSE ARGUMENTS
#--------------------------------------
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c|--customer)
        CUSTOMER="$2"
        shift 2
        ;;
      -s|--section)
        SECTION="$2"
        shift 2
        ;;
      -t|--type)
        FILE_TYPE="$2"
        shift 2
        ;;
      -r|--regex)
        USE_REGEX=true
        shift
        ;;
      -i|--case-sensitive)
        CASE_SENSITIVE=true
        shift
        ;;
      -n|--names-only)
        NAMES_ONLY=true
        shift
        ;;
      -C|--context)
        CONTEXT_LINES="$2"
        shift 2
        ;;
      -m|--max)
        MAX_RESULTS="$2"
        shift 2
        ;;
      --json)
        JSON_OUTPUT=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -*)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
      *)
        if [[ -z "$QUERY" ]]; then
          QUERY="$1"
        else
          log_error "Unexpected argument: $1"
          usage
          exit 1
        fi
        shift
        ;;
    esac
  done

  # Validate query
  if [[ -z "$QUERY" ]]; then
    log_error "No search query provided"
    echo ""
    usage
    exit 1
  fi
}

#--------------------------------------
# GET SEARCH PATH
#--------------------------------------
get_search_path() {
  local config_file="$SCRIPT_DIR/../config/cust-run-config.json"
  
  if [[ ! -f "$config_file" ]]; then
    log_error "Configuration file not found: $config_file"
    exit 1
  fi

  local vault_root
  vault_root=$(jq -r '.vault_root // empty' "$config_file")
  
  if [[ -z "$vault_root" ]] || [[ ! -d "$vault_root" ]]; then
    log_error "Vault root not configured or does not exist"
    exit 1
  fi

  local search_path="$vault_root"
  local prefix
  prefix=$(jq -r '.customer_prefix // "CustRun"' "$config_file")

  # Filter by customer if specified
  if [[ -n "$CUSTOMER" ]]; then
    local customer_path="$vault_root/${prefix}-${CUSTOMER}"
    if [[ ! -d "$customer_path" ]]; then
      log_error "Customer not found: $CUSTOMER"
      log_info "Available customers:"
      find "$vault_root" -maxdepth 1 -type d -name "${prefix}-*" -printf "  - %f\n" 2>/dev/null | sed "s/${prefix}-//"
      exit 1
    fi
    search_path="$customer_path"
  fi

  # Filter by section if specified
  if [[ -n "$SECTION" ]]; then
    if [[ -n "$CUSTOMER" ]]; then
      local section_path="$search_path/$SECTION"
      if [[ ! -d "$section_path" ]]; then
        log_error "Section not found: $SECTION in customer $CUSTOMER"
        exit 1
      fi
      search_path="$section_path"
    else
      # Section without customer - will search section in all customers
      search_path="$vault_root"
    fi
  fi

  echo "$search_path"
}

#--------------------------------------
# BUILD GREP OPTIONS
#--------------------------------------
build_grep_opts() {
  local opts="-n"  # Line numbers

  if [[ "$USE_REGEX" == "true" ]]; then
    opts="$opts -E"  # Extended regex
  else
    opts="$opts -F"  # Fixed string
  fi

  if [[ "$CASE_SENSITIVE" != "true" ]]; then
    opts="$opts -i"  # Case insensitive
  fi

  if [[ "$NAMES_ONLY" == "true" ]]; then
    opts="$opts -l"  # Files with matches only
  elif [[ "$CONTEXT_LINES" -gt 0 ]]; then
    opts="$opts -C $CONTEXT_LINES"  # Context lines
  fi

  opts="$opts --color=always"

  echo "$opts"
}

#--------------------------------------
# BUILD FIND PATTERN
#--------------------------------------
build_find_pattern() {
  local pattern=""

  if [[ "$FILE_TYPE" == "all" ]]; then
    pattern="-type f"
  else
    pattern="-type f -name \"*.$FILE_TYPE\""
  fi

  # Exclude hidden files and common non-content directories
  pattern="$pattern ! -path '*/.*' ! -path '*/_archive/*'"

  echo "$pattern"
}

#--------------------------------------
# FORMAT FILE PATH
#--------------------------------------
format_file_path() {
  local file_path="$1"
  local config_file="$SCRIPT_DIR/../config/cust-run-config.json"
  local vault_root
  vault_root=$(jq -r '.vault_root // empty' "$config_file")
  
  # Make path relative to vault root
  local relative_path="${file_path#$vault_root/}"
  echo "$relative_path"
}

#--------------------------------------
# SEARCH FILES
#--------------------------------------
search_files() {
  local search_path="$1"
  local grep_opts
  grep_opts=$(build_grep_opts)

  local config_file="$SCRIPT_DIR/../config/cust-run-config.json"
  local prefix
  prefix=$(jq -r '.customer_prefix // "CustRun"' "$config_file")

  # Build find command
  local find_cmd="find \"$search_path\" -type f"
  
  if [[ "$FILE_TYPE" != "all" ]]; then
    find_cmd="$find_cmd -name \"*.$FILE_TYPE\""
  fi
  
  # Exclude patterns
  find_cmd="$find_cmd ! -path '*/.*' ! -path '*/_archive/*'"

  # If section specified without customer, filter paths
  if [[ -n "$SECTION" ]] && [[ -z "$CUSTOMER" ]]; then
    find_cmd="$find_cmd -path \"*/${SECTION}/*\""
  fi

  local current_file=""
  local result_count=0

  # Execute search
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ ! -f "$file" ]] && continue
    
    if [[ "$result_count" -ge "$MAX_RESULTS" ]]; then
      if [[ "$JSON_OUTPUT" != "true" ]]; then
        echo ""
        echo -e "${YELLOW}Reached maximum results ($MAX_RESULTS). Use --max to increase.${NC}"
      fi
      break
    fi

    # Run grep on file
    local matches
    if matches=$(grep $grep_opts -- "$QUERY" "$file" 2>/dev/null); then
      ((FILE_COUNT++))
      
      local rel_path
      rel_path=$(format_file_path "$file")
      
      if [[ "$NAMES_ONLY" == "true" ]]; then
        if [[ "$JSON_OUTPUT" == "true" ]]; then
          JSON_RESULTS+=("{\"file\": \"$rel_path\"}")
        else
          echo -e "${CYAN}$rel_path${NC}"
        fi
        ((result_count++))
      else
        if [[ "$JSON_OUTPUT" != "true" ]]; then
          echo ""
          echo -e "${CYAN}━━━ ${BOLD}$rel_path${NC} ${CYAN}━━━${NC}"
        fi
        
        local line_num=""
        local content=""
        while IFS= read -r match_line; do
          ((MATCH_COUNT++))
          ((result_count++))
          
          if [[ "$JSON_OUTPUT" == "true" ]]; then
            # Parse line number from grep output
            if [[ "$match_line" =~ ^([0-9]+)[-:](.*)$ ]]; then
              line_num="${BASH_REMATCH[1]}"
              content="${BASH_REMATCH[2]}"
              # Escape JSON special chars
              content=$(echo "$content" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g')
              JSON_RESULTS+=("{\"file\": \"$rel_path\", \"line\": $line_num, \"content\": \"$content\"}")
            fi
          else
            echo "$match_line"
          fi
          
          if [[ "$result_count" -ge "$MAX_RESULTS" ]]; then
            break
          fi
        done <<< "$matches"
      fi
    fi
  done < <(eval "$find_cmd" 2>/dev/null)
}

#--------------------------------------
# PRINT RESULTS
#--------------------------------------
print_results() {
  if [[ "$JSON_OUTPUT" == "true" ]]; then
    echo "{"
    echo "  \"query\": \"$(echo "$QUERY" | sed 's/"/\\"/g')\","
    echo "  \"files_matched\": $FILE_COUNT,"
    echo "  \"total_matches\": $MATCH_COUNT,"
    echo "  \"results\": ["
    local first=true
    for result in "${JSON_RESULTS[@]}"; do
      if [[ "$first" == "true" ]]; then
        first=false
      else
        echo ","
      fi
      echo -n "    $result"
    done
    echo ""
    echo "  ]"
    echo "}"
    return
  fi

  echo ""
  echo -e "${DIM}$(printf '─%.0s' {1..60})${NC}"
  
  if [[ "$FILE_COUNT" -eq 0 ]]; then
    echo -e "${YELLOW}No matches found for:${NC} $QUERY"
  else
    if [[ "$NAMES_ONLY" == "true" ]]; then
      echo -e "${GREEN}Found $FILE_COUNT file(s)${NC} matching: ${BOLD}$QUERY${NC}"
    else
      echo -e "${GREEN}Found $MATCH_COUNT match(es) in $FILE_COUNT file(s)${NC} for: ${BOLD}$QUERY${NC}"
    fi
  fi
  echo ""
}

#--------------------------------------
# MAIN
#--------------------------------------
main() {
  parse_args "$@"

  if [[ "$JSON_OUTPUT" != "true" ]]; then
    echo ""
    echo -e "${CYAN}🔍 Searching vault...${NC}"
    
    local search_info=""
    [[ -n "$CUSTOMER" ]] && search_info+=" customer=${CYAN}$CUSTOMER${NC}"
    [[ -n "$SECTION" ]] && search_info+=" section=${CYAN}$SECTION${NC}"
    [[ "$FILE_TYPE" != "md" ]] && search_info+=" type=${CYAN}$FILE_TYPE${NC}"
    [[ "$USE_REGEX" == "true" ]] && search_info+=" ${YELLOW}(regex)${NC}"
    [[ "$CASE_SENSITIVE" == "true" ]] && search_info+=" ${YELLOW}(case-sensitive)${NC}"
    
    if [[ -n "$search_info" ]]; then
      echo -e "  Filters:$search_info"
    fi
  fi

  local search_path
  search_path=$(get_search_path)

  search_files "$search_path"
  print_results
}

main "$@"
