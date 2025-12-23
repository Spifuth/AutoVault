#!/usr/bin/env bash
#===============================================================================
#
#  SCRIPT NAME:    Manage-Encryption.sh
#  DESCRIPTION:    Encrypt and decrypt sensitive notes in the vault
#                  Uses GPG or age for encryption
#
#  USAGE:          ./Manage-Encryption.sh <subcommand> [options]
#
#  SUBCOMMANDS:    encrypt     Encrypt a file or folder
#                  decrypt     Decrypt a file or folder
#                  status      Show encryption status
#                  init        Initialize encryption (create keys)
#                  lock        Encrypt all sensitive notes
#                  unlock      Decrypt all sensitive notes
#
#  AUTHOR:         AutoVault Project
#  VERSION:        2.4.0
#
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"

# Source UI library if available
if [[ -f "$SCRIPT_DIR/lib/ui.sh" ]]; then
    source "$SCRIPT_DIR/lib/ui.sh"
    UI_AVAILABLE=true
else
    UI_AVAILABLE=false
fi

# Source config
source "$SCRIPT_DIR/lib/config.sh"
load_config || true

#--------------------------------------
# CONFIGURATION
#--------------------------------------
ENCRYPTION_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/autovault/encryption"
# shellcheck disable=SC2034  # Reserved for future use - key file path for age encryption
ENCRYPTION_KEY_FILE="$ENCRYPTION_CONFIG_DIR/key.age"
# shellcheck disable=SC2034  # Reserved for future use - marker file for encrypted vaults
ENCRYPTION_MARKER=".encrypted"
SENSITIVE_FOLDER="${SENSITIVE_FOLDER:-_private}"

# Encryption backend: "age" (preferred) or "gpg"
ENCRYPTION_BACKEND="${ENCRYPTION_BACKEND:-auto}"

#--------------------------------------
# USAGE
#--------------------------------------
usage() {
  cat << EOF
${BOLD:-}USAGE${NC:-}
    $(basename "$0") <SUBCOMMAND> [OPTIONS]

${BOLD:-}DESCRIPTION${NC:-}
    Encrypt and decrypt sensitive notes in your vault.
    Supports 'age' (recommended) or GPG encryption.

${BOLD:-}SUBCOMMANDS${NC:-}
    init                    Initialize encryption (generate keys)
    encrypt <file|folder>   Encrypt a file or folder
    decrypt <file|folder>   Decrypt a file or folder
    status                  Show encryption status
    lock                    Encrypt all notes in _private folder
    unlock                  Decrypt all notes in _private folder

${BOLD:-}OPTIONS${NC:-}
    -b, --backend <age|gpg> Choose encryption backend
    -p, --password          Use password instead of key file
    -h, --help              Show this help message

${BOLD:-}EXAMPLES${NC:-}
    # Initialize encryption
    $(basename "$0") init

    # Encrypt a single file
    $(basename "$0") encrypt path/to/secret.md

    # Encrypt an entire folder
    $(basename "$0") encrypt path/to/folder/

    # Decrypt
    $(basename "$0") decrypt path/to/secret.md.age

    # Lock all private notes
    $(basename "$0") lock

    # Unlock for editing
    $(basename "$0") unlock

${BOLD:-}SENSITIVE FOLDER${NC:-}
    By default, the \`$SENSITIVE_FOLDER\` folder in each customer directory
    is considered sensitive. Use 'lock' and 'unlock' to manage these files.

${BOLD:-}CONFIGURATION${NC:-}
    Keys directory: $ENCRYPTION_CONFIG_DIR
    Backend: $ENCRYPTION_BACKEND

EOF
}

#--------------------------------------
# DETECT BACKEND
#--------------------------------------
detect_backend() {
    if [[ "$ENCRYPTION_BACKEND" != "auto" ]]; then
        echo "$ENCRYPTION_BACKEND"
        return
    fi
    
    if command -v age &>/dev/null; then
        echo "age"
    elif command -v gpg &>/dev/null; then
        echo "gpg"
    else
        echo "none"
    fi
}

#--------------------------------------
# CHECK REQUIREMENTS
#--------------------------------------
check_requirements() {
    local backend
    backend=$(detect_backend)
    
    case "$backend" in
        age)
            if ! command -v age &>/dev/null; then
                log_error "age is not installed"
                echo "Install with: brew install age / apt install age"
                return 1
            fi
            ;;
        gpg)
            if ! command -v gpg &>/dev/null; then
                log_error "gpg is not installed"
                echo "Install with: brew install gnupg / apt install gnupg"
                return 1
            fi
            ;;
        none)
            log_error "No encryption backend available"
            echo "Install 'age' (recommended) or 'gpg'"
            echo ""
            echo "  age: https://github.com/FiloSottile/age"
            echo "  gpg: https://gnupg.org/"
            return 1
            ;;
    esac
}

#--------------------------------------
# INIT
#--------------------------------------
cmd_init() {
    local use_password=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--password)
                use_password=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    check_requirements || exit 1
    
    local backend
    backend=$(detect_backend)
    
    mkdir -p "$ENCRYPTION_CONFIG_DIR"
    chmod 700 "$ENCRYPTION_CONFIG_DIR"
    
    if [[ "$UI_AVAILABLE" == "true" ]]; then
        print_section "Initialize Encryption"
        echo ""
    else
        echo "Initialize Encryption"
        echo "====================="
    fi
    
    echo "Backend: $backend"
    echo ""
    
    case "$backend" in
        age)
            if [[ "$use_password" == "true" ]]; then
                echo "Using password-based encryption."
                echo "You will be prompted for a password when encrypting/decrypting."
                echo ""
                touch "$ENCRYPTION_CONFIG_DIR/use-password"
                log_success "Password-based encryption configured"
            else
                # Generate age key pair
                local key_file="$ENCRYPTION_CONFIG_DIR/key.txt"
                local pub_file="$ENCRYPTION_CONFIG_DIR/key.pub"
                
                if [[ -f "$key_file" ]]; then
                    log_warn "Key already exists: $key_file"
                    read -rp "Overwrite? [y/N] " confirm
                    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                        echo "Cancelled"
                        exit 0
                    fi
                fi
                
                age-keygen -o "$key_file" 2> >(tee "$pub_file" >&2)
                chmod 600 "$key_file"
                
                log_success "Age key generated"
                echo ""
                echo "Private key: $key_file"
                echo "Public key:  $(cat "$pub_file" | grep 'public key:')"
                echo ""
                echo "⚠️  BACKUP YOUR PRIVATE KEY! If lost, encrypted files cannot be recovered."
            fi
            ;;
            
        gpg)
            echo "Using GPG encryption."
            echo ""
            
            # Check for existing keys
            local gpg_keys
            gpg_keys=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | grep -c "sec" || echo "0")
            
            if [[ "$gpg_keys" -gt 0 ]]; then
                echo "Found $gpg_keys existing GPG key(s)."
                gpg --list-secret-keys --keyid-format LONG 2>/dev/null | head -20
                echo ""
                read -rp "Use existing key? [Y/n] " use_existing
                
                if [[ ! "$use_existing" =~ ^[Nn]$ ]]; then
                    read -rp "Enter key ID or email: " key_id
                    echo "$key_id" > "$ENCRYPTION_CONFIG_DIR/gpg-key-id"
                    log_success "GPG key configured: $key_id"
                    return 0
                fi
            fi
            
            echo "Generate a new GPG key with: gpg --full-generate-key"
            echo "Then run this command again."
            ;;
    esac
    
    # Create encryption marker for vault
    if [[ -n "${VAULT_ROOT:-}" ]]; then
        mkdir -p "$VAULT_ROOT/.autovault"
        echo "$backend" > "$VAULT_ROOT/.autovault/encryption-backend"
        log_info "Vault configured for $backend encryption"
    fi
}

#--------------------------------------
# ENCRYPT FILE
#--------------------------------------
encrypt_file() {
    local file="$1"
    local backend
    backend=$(detect_backend)
    
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi
    
    local output="${file}.age"
    
    case "$backend" in
        age)
            if [[ -f "$ENCRYPTION_CONFIG_DIR/use-password" ]]; then
                age -p -o "$output" "$file"
            else
                local key_file="$ENCRYPTION_CONFIG_DIR/key.txt"
                local recipient
                recipient=$(grep "public key:" "$ENCRYPTION_CONFIG_DIR/key.pub" | awk '{print $NF}')
                age -r "$recipient" -o "$output" "$file"
            fi
            ;;
        gpg)
            output="${file}.gpg"
            local key_id
            if [[ -f "$ENCRYPTION_CONFIG_DIR/gpg-key-id" ]]; then
                key_id=$(cat "$ENCRYPTION_CONFIG_DIR/gpg-key-id")
                gpg --encrypt --recipient "$key_id" --output "$output" "$file"
            else
                gpg --symmetric --output "$output" "$file"
            fi
            ;;
    esac
    
    if [[ -f "$output" ]]; then
        rm -f "$file"
        log_info "Encrypted: $file → $output"
    else
        log_error "Encryption failed: $file"
        return 1
    fi
}

#--------------------------------------
# DECRYPT FILE
#--------------------------------------
decrypt_file() {
    local file="$1"
    local backend
    backend=$(detect_backend)
    
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi
    
    local output=""
    
    case "$backend" in
        age)
            if [[ "$file" != *.age ]]; then
                log_error "Not an age-encrypted file: $file"
                return 1
            fi
            output="${file%.age}"
            
            if [[ -f "$ENCRYPTION_CONFIG_DIR/use-password" ]]; then
                age -d -o "$output" "$file"
            else
                local key_file="$ENCRYPTION_CONFIG_DIR/key.txt"
                age -d -i "$key_file" -o "$output" "$file"
            fi
            ;;
        gpg)
            if [[ "$file" != *.gpg ]]; then
                log_error "Not a GPG-encrypted file: $file"
                return 1
            fi
            output="${file%.gpg}"
            gpg --decrypt --output "$output" "$file"
            ;;
    esac
    
    if [[ -f "$output" ]]; then
        rm -f "$file"
        log_info "Decrypted: $file → $output"
    else
        log_error "Decryption failed: $file"
        return 1
    fi
}

#--------------------------------------
# ENCRYPT COMMAND
#--------------------------------------
cmd_encrypt() {
    local target="${1:-}"
    
    if [[ -z "$target" ]]; then
        log_error "File or folder required"
        echo "Usage: $(basename "$0") encrypt <file|folder>"
        exit 1
    fi
    
    check_requirements || exit 1
    
    if [[ -f "$target" ]]; then
        encrypt_file "$target"
    elif [[ -d "$target" ]]; then
        local count=0
        while IFS= read -r -d '' file; do
            encrypt_file "$file"
            ((count++)) || true
        done < <(find "$target" -type f -name "*.md" -print0)
        log_success "Encrypted $count file(s)"
    else
        log_error "Not found: $target"
        exit 1
    fi
}

#--------------------------------------
# DECRYPT COMMAND
#--------------------------------------
cmd_decrypt() {
    local target="${1:-}"
    
    if [[ -z "$target" ]]; then
        log_error "File or folder required"
        echo "Usage: $(basename "$0") decrypt <file|folder>"
        exit 1
    fi
    
    check_requirements || exit 1
    
    local backend
    backend=$(detect_backend)
    local ext="age"
    [[ "$backend" == "gpg" ]] && ext="gpg"
    
    if [[ -f "$target" ]]; then
        decrypt_file "$target"
    elif [[ -d "$target" ]]; then
        local count=0
        while IFS= read -r -d '' file; do
            decrypt_file "$file"
            ((count++)) || true
        done < <(find "$target" -type f -name "*.$ext" -print0)
        log_success "Decrypted $count file(s)"
    else
        log_error "Not found: $target"
        exit 1
    fi
}

#--------------------------------------
# STATUS
#--------------------------------------
cmd_status() {
    local backend
    backend=$(detect_backend)
    
    if [[ "$UI_AVAILABLE" == "true" ]]; then
        print_section "Encryption Status"
        echo ""
        print_kv "Backend" "$backend"
        print_kv "Config Dir" "$ENCRYPTION_CONFIG_DIR"
    else
        echo "Encryption Status"
        echo "================="
        echo "Backend: $backend"
        echo "Config: $ENCRYPTION_CONFIG_DIR"
    fi
    
    # Check initialization
    echo ""
    case "$backend" in
        age)
            if [[ -f "$ENCRYPTION_CONFIG_DIR/use-password" ]]; then
                echo -e "${GREEN:-}✓${NC:-} Password-based encryption configured"
            elif [[ -f "$ENCRYPTION_CONFIG_DIR/key.txt" ]]; then
                echo -e "${GREEN:-}✓${NC:-} Key file exists"
            else
                echo -e "${RED:-}✗${NC:-} Not initialized. Run: $(basename "$0") init"
            fi
            ;;
        gpg)
            if [[ -f "$ENCRYPTION_CONFIG_DIR/gpg-key-id" ]]; then
                local key_id
                key_id=$(cat "$ENCRYPTION_CONFIG_DIR/gpg-key-id")
                echo -e "${GREEN:-}✓${NC:-} GPG key configured: $key_id"
            else
                echo -e "${YELLOW:-}!${NC:-} Using default GPG key"
            fi
            ;;
        none)
            echo -e "${RED:-}✗${NC:-} No encryption backend available"
            ;;
    esac
    
    # Count encrypted files in vault
    if [[ -n "${VAULT_ROOT:-}" && -d "$VAULT_ROOT" ]]; then
        echo ""
        local age_count gpg_count md_private
        age_count=$(find "$VAULT_ROOT" -name "*.age" 2>/dev/null | wc -l) || age_count=0
        gpg_count=$(find "$VAULT_ROOT" -name "*.gpg" 2>/dev/null | wc -l) || gpg_count=0
        md_private=$(find "$VAULT_ROOT" -path "*/$SENSITIVE_FOLDER/*.md" 2>/dev/null | wc -l) || md_private=0
        
        echo "Vault: $VAULT_ROOT"
        echo "  Encrypted (age): $age_count files"
        echo "  Encrypted (gpg): $gpg_count files"
        echo "  Unencrypted in $SENSITIVE_FOLDER: $md_private files"
    fi
}

#--------------------------------------
# LOCK (encrypt all private)
#--------------------------------------
cmd_lock() {
    if [[ -z "${VAULT_ROOT:-}" ]]; then
        log_error "VAULT_ROOT not set"
        exit 1
    fi
    
    check_requirements || exit 1
    
    local backend
    backend=$(detect_backend)
    
    log_info "Locking all files in $SENSITIVE_FOLDER folders..."
    
    local count=0
    local ext="md"
    
    while IFS= read -r -d '' file; do
        encrypt_file "$file"
        ((count++)) || true
    done < <(find "$VAULT_ROOT" -path "*/$SENSITIVE_FOLDER/*.$ext" -type f -print0 2>/dev/null)
    
    if [[ $count -gt 0 ]]; then
        log_success "Locked $count file(s)"
    else
        log_info "No files to lock"
    fi
}

#--------------------------------------
# UNLOCK (decrypt all private)
#--------------------------------------
cmd_unlock() {
    if [[ -z "${VAULT_ROOT:-}" ]]; then
        log_error "VAULT_ROOT not set"
        exit 1
    fi
    
    check_requirements || exit 1
    
    local backend
    backend=$(detect_backend)
    local ext="age"
    [[ "$backend" == "gpg" ]] && ext="gpg"
    
    log_info "Unlocking all files in $SENSITIVE_FOLDER folders..."
    
    local count=0
    
    while IFS= read -r -d '' file; do
        decrypt_file "$file"
        ((count++)) || true
    done < <(find "$VAULT_ROOT" -path "*/$SENSITIVE_FOLDER/*.$ext" -type f -print0 2>/dev/null)
    
    if [[ $count -gt 0 ]]; then
        log_success "Unlocked $count file(s)"
    else
        log_info "No files to unlock"
    fi
}

#--------------------------------------
# MAIN
#--------------------------------------
main() {
    local cmd="${1:-}"
    shift || true
    
    case "$cmd" in
        -h|--help|help|"")
            usage
            ;;
        init|setup)
            cmd_init "$@"
            ;;
        encrypt|enc)
            cmd_encrypt "$@"
            ;;
        decrypt|dec)
            cmd_decrypt "$@"
            ;;
        status)
            cmd_status
            ;;
        lock)
            cmd_lock
            ;;
        unlock)
            cmd_unlock
            ;;
        *)
            log_error "Unknown command: $cmd"
            usage
            exit 1
            ;;
    esac
}

main "$@"
