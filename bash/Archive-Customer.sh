#!/usr/bin/env bash
#===============================================================================
#
#  SCRIPT NAME:    Archive-Customer.sh
#  DESCRIPTION:    Archive a customer to a compressed file and optionally remove
#                  from active vault
#
#  USAGE:          ./Archive-Customer.sh <customer_id> [options]
#
#  OPTIONS:        --remove         Remove customer after archiving
#                  --output <path>  Custom output path for archive
#                  --format <type>  Archive format: zip, tar.gz, tar.bz2 (default: zip)
#                  --no-compress    Create uncompressed archive
#                  --encrypt        Encrypt archive with password
#                  --force          Overwrite existing archive
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
CUSTOMER_ID=""
REMOVE_AFTER=false
OUTPUT_PATH=""
FORMAT="zip"
# shellcheck disable=SC2034  # Used implicitly via FORMAT setting
NO_COMPRESS=false
ENCRYPT=false
FORCE=false

#--------------------------------------
# USAGE
#--------------------------------------
usage() {
  cat << EOF
${BOLD}USAGE${NC}
    $(basename "$0") <customer_id> [OPTIONS]

${BOLD}DESCRIPTION${NC}
    Archive a customer's data to a compressed file.
    Archives are stored in the vault's _archive directory by default.

${BOLD}ARGUMENTS${NC}
    <customer_id>         The customer ID to archive (without prefix)

${BOLD}OPTIONS${NC}
    -r, --remove          Remove customer from vault after archiving
    -o, --output <path>   Custom output path for the archive file
    -f, --format <type>   Archive format (default: zip)
                          Supported: zip, tar.gz, tar.bz2, tar
    --no-compress         Create uncompressed tar archive
    -e, --encrypt         Encrypt archive with password (zip only)
    --force               Overwrite existing archive without asking
    -h, --help            Show this help message

${BOLD}EXAMPLES${NC}
    # Archive customer ACME
    $(basename "$0") ACME

    # Archive and remove from vault
    $(basename "$0") ACME --remove

    # Archive with custom format
    $(basename "$0") ACME --format tar.gz

    # Archive to specific location
    $(basename "$0") ACME --output ~/backups/acme-archive.zip

    # Archive with encryption
    $(basename "$0") ACME --encrypt

EOF
}

#--------------------------------------
# PARSE ARGUMENTS
#--------------------------------------
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -r|--remove)
        REMOVE_AFTER=true
        shift
        ;;
      -o|--output)
        OUTPUT_PATH="$2"
        shift 2
        ;;
      -f|--format)
        FORMAT="$2"
        shift 2
        ;;
      --no-compress)
        # shellcheck disable=SC2034  # Used implicitly via FORMAT setting
        NO_COMPRESS=true
        FORMAT="tar"
        shift
        ;;
      -e|--encrypt)
        ENCRYPT=true
        shift
        ;;
      --force)
        FORCE=true
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
        if [[ -z "$CUSTOMER_ID" ]]; then
          CUSTOMER_ID="$1"
        else
          log_error "Unexpected argument: $1"
          usage
          exit 1
        fi
        shift
        ;;
    esac
  done

  # Validate customer ID
  if [[ -z "$CUSTOMER_ID" ]]; then
    log_error "Customer ID is required"
    echo ""
    usage
    exit 1
  fi

  # Validate format
  case "$FORMAT" in
    zip|tar|tar.gz|tar.bz2) ;;
    *)
      log_error "Invalid format: $FORMAT"
      log_info "Supported formats: zip, tar, tar.gz, tar.bz2"
      exit 1
      ;;
  esac

  # Encrypt only with zip
  if [[ "$ENCRYPT" == "true" ]] && [[ "$FORMAT" != "zip" ]]; then
    log_error "Encryption is only supported with zip format"
    exit 1
  fi
}

#--------------------------------------
# GET CUSTOMER PATH
#--------------------------------------
get_customer_path() {
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

  local prefix
  prefix=$(jq -r '.customer_prefix // "CustRun"' "$config_file")
  
  local customer_path="$vault_root/${prefix}-${CUSTOMER_ID}"
  
  if [[ ! -d "$customer_path" ]]; then
    log_error "Customer not found: $CUSTOMER_ID"
    log_info "Available customers:"
    find "$vault_root" -maxdepth 1 -type d -name "${prefix}-*" -printf "  - %f\n" 2>/dev/null | sed "s/${prefix}-//"
    exit 1
  fi

  echo "$customer_path"
}

#--------------------------------------
# GET ARCHIVE PATH
#--------------------------------------
get_archive_path() {
  local customer_path="$1"
  local config_file="$SCRIPT_DIR/../config/cust-run-config.json"
  local vault_root
  vault_root=$(jq -r '.vault_root // empty' "$config_file")
  local prefix
  prefix=$(jq -r '.customer_prefix // "CustRun"' "$config_file")

  # Use custom path if specified
  if [[ -n "$OUTPUT_PATH" ]]; then
    echo "$OUTPUT_PATH"
    return
  fi

  # Default: vault/_archive/
  local archive_dir="$vault_root/_archive"
  mkdir -p "$archive_dir"

  # Generate filename with date
  local date_stamp
  date_stamp=$(date +%Y%m%d)
  local archive_name="${prefix}-${CUSTOMER_ID}_${date_stamp}"

  case "$FORMAT" in
    zip)      echo "$archive_dir/${archive_name}.zip" ;;
    tar)      echo "$archive_dir/${archive_name}.tar" ;;
    tar.gz)   echo "$archive_dir/${archive_name}.tar.gz" ;;
    tar.bz2)  echo "$archive_dir/${archive_name}.tar.bz2" ;;
  esac
}

#--------------------------------------
# CALCULATE SIZE
#--------------------------------------
calculate_size() {
  local path="$1"
  du -sh "$path" 2>/dev/null | cut -f1
}

#--------------------------------------
# COUNT FILES
#--------------------------------------
count_files() {
  local path="$1"
  find "$path" -type f 2>/dev/null | wc -l
}

#--------------------------------------
# CREATE ARCHIVE
#--------------------------------------
create_archive() {
  local customer_path="$1"
  local archive_path="$2"
  local customer_name
  customer_name=$(basename "$customer_path")

  # Check if archive exists
  if [[ -f "$archive_path" ]]; then
    if [[ "$FORCE" != "true" ]]; then
      read -rp "Archive already exists. Overwrite? [y/N] " confirm
      if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Archive cancelled"
        exit 0
      fi
    fi
    rm -f "$archive_path"
  fi

  local parent_dir
  parent_dir=$(dirname "$customer_path")

  log_info "Creating archive..."
  
  case "$FORMAT" in
    zip)
      if [[ "$ENCRYPT" == "true" ]]; then
        echo -e "${YELLOW}Enter password for encrypted archive:${NC}"
        (cd "$parent_dir" && zip -rq -e "$archive_path" "$customer_name")
      else
        (cd "$parent_dir" && zip -rq "$archive_path" "$customer_name")
      fi
      ;;
    tar)
      (cd "$parent_dir" && tar -cf "$archive_path" "$customer_name")
      ;;
    tar.gz)
      (cd "$parent_dir" && tar -czf "$archive_path" "$customer_name")
      ;;
    tar.bz2)
      (cd "$parent_dir" && tar -cjf "$archive_path" "$customer_name")
      ;;
  esac

  if [[ ! -f "$archive_path" ]]; then
    log_error "Failed to create archive"
    exit 1
  fi

  local archive_size
  archive_size=$(calculate_size "$archive_path")
  log_success "Archive created: $archive_path ($archive_size)"
}

#--------------------------------------
# REMOVE CUSTOMER
#--------------------------------------
remove_customer() {
  local customer_path="$1"

  if [[ "$FORCE" != "true" ]]; then
    echo ""
    echo -e "${YELLOW}${BOLD}WARNING:${NC} This will permanently delete the customer folder:"
    echo -e "  ${RED}$customer_path${NC}"
    echo ""
    read -rp "Are you sure you want to remove this customer? [y/N] " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      log_info "Customer not removed"
      return
    fi
  fi

  log_info "Removing customer folder..."
  rm -rf "$customer_path"
  log_success "Customer removed from vault"
}

#--------------------------------------
# MAIN
#--------------------------------------
main() {
  parse_args "$@"

  echo ""
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║${NC}                                                              ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}    ${BOLD}📦 Archive Customer${NC}                                       ${CYAN}║${NC}"
  echo -e "${CYAN}║${NC}                                                              ${CYAN}║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
  echo ""

  local customer_path
  customer_path=$(get_customer_path)

  local archive_path
  archive_path=$(get_archive_path "$customer_path")

  # Display info
  local original_size
  original_size=$(calculate_size "$customer_path")
  local file_count
  file_count=$(count_files "$customer_path")

  echo -e "${BOLD}Customer:${NC}   $CUSTOMER_ID"
  echo -e "${BOLD}Location:${NC}   $customer_path"
  echo -e "${BOLD}Size:${NC}       $original_size"
  echo -e "${BOLD}Files:${NC}      $file_count"
  echo ""
  echo -e "${BOLD}Archive:${NC}"
  echo -e "  Format:   $FORMAT"
  echo -e "  Output:   $archive_path"
  [[ "$ENCRYPT" == "true" ]] && echo -e "  ${YELLOW}Encrypted: yes${NC}"
  [[ "$REMOVE_AFTER" == "true" ]] && echo -e "  ${RED}Remove after: yes${NC}"
  echo ""

  # Confirm
  if [[ "$FORCE" != "true" ]]; then
    read -rp "Proceed with archive? [Y/n] " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
      log_info "Archive cancelled"
      exit 0
    fi
  fi

  # Create archive
  create_archive "$customer_path" "$archive_path"

  # Remove if requested
  if [[ "$REMOVE_AFTER" == "true" ]]; then
    remove_customer "$customer_path"
  fi

  # Summary
  echo ""
  echo -e "${GREEN}${BOLD}✓ Archive complete!${NC}"
  echo ""
  echo -e "  Archive: ${CYAN}$archive_path${NC}"
  
  local archive_size
  archive_size=$(calculate_size "$archive_path")
  echo -e "  Size:    $archive_size"
  
  if [[ "$REMOVE_AFTER" == "true" ]]; then
    echo -e "  Status:  ${YELLOW}Customer removed from vault${NC}"
  else
    echo -e "  Status:  Customer still in vault"
  fi
  echo ""

  # Restore instructions
  echo -e "${DIM}To restore this customer:${NC}"
  case "$FORMAT" in
    zip)
      if [[ "$ENCRYPT" == "true" ]]; then
        echo -e "${DIM}  unzip -d <vault_root> $archive_path${NC}"
      else
        echo -e "${DIM}  unzip -d <vault_root> $archive_path${NC}"
      fi
      ;;
    tar)
      echo -e "${DIM}  tar -xf $archive_path -C <vault_root>${NC}"
      ;;
    tar.gz)
      echo -e "${DIM}  tar -xzf $archive_path -C <vault_root>${NC}"
      ;;
    tar.bz2)
      echo -e "${DIM}  tar -xjf $archive_path -C <vault_root>${NC}"
      ;;
  esac
  echo ""
}

main "$@"
