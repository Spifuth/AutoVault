#!/usr/bin/env bash
#===============================================================================
#
#  AUTOVAULT LIBRARY - remote.sh
#
#===============================================================================
#
#  DESCRIPTION:    Remote vault synchronization via SSH/rsync.
#                  Allows syncing vault to/from remote servers.
#
#  FEATURES:       - Multiple remote configurations
#                  - Push/pull sync operations
#                  - Dry-run preview
#                  - Bandwidth limiting
#                  - Exclude patterns
#
#  REMOTES CONFIG: Stored in config/remotes.json
#                  {
#                    "remotes": {
#                      "server1": {
#                        "host": "user@server.com",
#                        "path": "/path/to/vault",
#                        "port": 22,
#                        "excludes": [".obsidian/workspace*"]
#                      }
#                    }
#                  }
#
#  USAGE:          source "$LIB_DIR/remote.sh"
#                  remote_push "server1"
#                  remote_pull "server1"
#
#===============================================================================

# Prevent multiple sourcing
[[ -n "${_REMOTE_SH_LOADED:-}" ]] && return 0
_REMOTE_SH_LOADED=1

#--------------------------------------
# CONFIGURATION
#--------------------------------------
REMOTES_JSON="${REMOTES_JSON:-}"
# shellcheck disable=SC2034  # Used by functions in this module
DEFAULT_SSH_PORT=22
# shellcheck disable=SC2034  # Used by rsync operations
DEFAULT_RSYNC_OPTS="-avz --progress --delete"

#--------------------------------------
# FIND REMOTES CONFIG
#--------------------------------------
find_remotes_config() {
    if [[ -n "$REMOTES_JSON" ]] && [[ -f "$REMOTES_JSON" ]]; then
        echo "$REMOTES_JSON"
        return 0
    fi
    
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    if [[ -f "$script_dir/config/remotes.json" ]]; then
        echo "$script_dir/config/remotes.json"
        return 0
    fi
    
    return 1
}

#--------------------------------------
# INIT REMOTES CONFIG
#--------------------------------------
init_remotes_config() {
    local config_file
    
    # Use REMOTES_JSON if set, otherwise default location
    if [[ -n "$REMOTES_JSON" ]]; then
        config_file="$REMOTES_JSON"
    else
        config_file="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/config/remotes.json"
    fi
    
    if [[ -f "$config_file" ]]; then
        log_warn "Remotes config already exists: $config_file"
        return 0
    fi
    
    log_info "Creating remotes configuration..."
    
    # Ensure directory exists
    mkdir -p "$(dirname "$config_file")"
    
    cat > "$config_file" << 'EOF'
{
  "remotes": {},
  "defaults": {
    "port": 22,
    "rsync_opts": "-avz --progress --delete",
    "excludes": [
      ".obsidian/workspace.json",
      ".obsidian/workspace-mobile.json",
      ".trash/"
    ]
  }
}
EOF
    
    log_success "Created: $config_file"
    echo ""
    echo "Add a remote with: cust-run-config.sh remote add <name> <user@host> <path>"
}

#--------------------------------------
# GET REMOTE CONFIG
#--------------------------------------
get_remote() {
    local name="$1"
    local config_file
    
    config_file=$(find_remotes_config) || {
        log_error "No remotes configuration found"
        log_info "Run: cust-run-config.sh remote init"
        return 1
    }
    
    local remote
    remote=$(jq -r ".remotes[\"$name\"] // empty" "$config_file")
    
    if [[ -z "$remote" ]]; then
        log_error "Remote '$name' not found"
        return 1
    fi
    
    echo "$remote"
}

#--------------------------------------
# LIST REMOTES
#--------------------------------------
list_remotes() {
    local config_file
    config_file=$(find_remotes_config) || {
        log_warn "No remotes configuration found"
        log_info "Run: cust-run-config.sh remote init"
        return 0
    }
    
    echo ""
    echo "Configured Remotes:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    local remotes
    remotes=$(jq -r '.remotes | keys[]' "$config_file" 2>/dev/null)
    
    if [[ -z "$remotes" ]]; then
        echo "  (no remotes configured)"
        echo ""
        echo "Add a remote with:"
        echo "  cust-run-config.sh remote add <name> <user@host> <path>"
        return 0
    fi
    
    while IFS= read -r name; do
        local host path port
        host=$(jq -r ".remotes[\"$name\"].host" "$config_file")
        path=$(jq -r ".remotes[\"$name\"].path" "$config_file")
        port=$(jq -r ".remotes[\"$name\"].port // 22" "$config_file")
        
        printf "  ${CYAN}%s${NC}\n" "$name"
        printf "    Host: %s (port %s)\n" "$host" "$port"
        printf "    Path: %s\n" "$path"
        
        # Test connection (quick) - use -n to prevent SSH from consuming stdin
        if ssh -n -o BatchMode=yes -o ConnectTimeout=3 -p "$port" "$host" "exit" 2>/dev/null; then
            printf "    Status: ${GREEN}✓ reachable${NC}\n"
        else
            printf "    Status: ${YELLOW}? unreachable or needs auth${NC}\n"
        fi
        echo ""
    done <<< "$remotes"
}

#--------------------------------------
# ADD REMOTE
#--------------------------------------
add_remote() {
    local name="$1"
    local host="$2"
    local path="$3"
    local port="${4:-22}"
    
    if [[ -z "$name" ]] || [[ -z "$host" ]] || [[ -z "$path" ]]; then
        log_error "Usage: remote add <name> <user@host> <remote-path> [port]"
        return 1
    fi
    
    # Validate name (alphanumeric + dash/underscore)
    if ! [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Remote name must be alphanumeric (can include - and _)"
        return 1
    fi
    
    local config_file
    config_file=$(find_remotes_config) || {
        init_remotes_config
        config_file=$(find_remotes_config)
    }
    
    # Check if already exists
    if jq -e ".remotes[\"$name\"]" "$config_file" >/dev/null 2>&1; then
        log_warn "Remote '$name' already exists. Use 'remote remove' first to replace."
        return 1
    fi
    
    # Dry-run check
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY-RUN] Would add remote '$name': $host:$path"
        return 0
    fi
    
    # Add to config
    local tmp_file
    tmp_file=$(mktemp)
    
    jq ".remotes[\"$name\"] = {
        \"host\": \"$host\",
        \"path\": \"$path\",
        \"port\": $port,
        \"excludes\": []
    }" "$config_file" > "$tmp_file" && mv "$tmp_file" "$config_file"
    
    log_success "Added remote '$name'"
    echo ""
    echo "  Host: $host"
    echo "  Path: $path"
    echo "  Port: $port"
    echo ""
    echo "Test with: cust-run-config.sh remote test $name"
}

#--------------------------------------
# REMOVE REMOTE
#--------------------------------------
remove_remote() {
    local name="$1"
    
    if [[ -z "$name" ]]; then
        log_error "Usage: remote remove <name>"
        return 1
    fi
    
    local config_file
    config_file=$(find_remotes_config) || {
        log_error "No remotes configuration found"
        return 1
    }
    
    # Check exists
    if ! jq -e ".remotes[\"$name\"]" "$config_file" >/dev/null 2>&1; then
        log_error "Remote '$name' not found"
        return 1
    fi
    
    # Dry-run check
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY-RUN] Would remove remote '$name'"
        return 0
    fi
    
    # Remove from config
    local tmp_file
    tmp_file=$(mktemp)
    
    jq "del(.remotes[\"$name\"])" "$config_file" > "$tmp_file" && mv "$tmp_file" "$config_file"
    
    log_success "Removed remote '$name'"
}

#--------------------------------------
# TEST REMOTE CONNECTION
#--------------------------------------
test_remote() {
    local name="$1"
    
    if [[ -z "$name" ]]; then
        log_error "Usage: remote test <name>"
        return 1
    fi
    
    local config_file
    config_file=$(find_remotes_config) || {
        log_error "No remotes configuration found"
        return 1
    }
    
    local host path port
    host=$(jq -r ".remotes[\"$name\"].host // empty" "$config_file")
    path=$(jq -r ".remotes[\"$name\"].path // empty" "$config_file")
    port=$(jq -r ".remotes[\"$name\"].port // 22" "$config_file")
    
    if [[ -z "$host" ]]; then
        log_error "Remote '$name' not found"
        return 1
    fi
    
    log_info "Testing connection to '$name'..."
    echo ""
    
    # Test SSH connection
    echo -n "  SSH connection: "
    if ssh -o BatchMode=yes -o ConnectTimeout=5 -p "$port" "$host" "echo OK" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        log_error "SSH connection failed"
        log_info "Make sure you can connect with: ssh -p $port $host"
        return 1
    fi
    
    # Test remote path exists
    echo -n "  Remote path exists: "
    if ssh -o BatchMode=yes -p "$port" "$host" "test -d '$path'" 2>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}✗ (will be created on push)${NC}"
    fi
    
    # Test rsync available
    echo -n "  rsync available: "
    if ssh -o BatchMode=yes -p "$port" "$host" "command -v rsync" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        log_error "rsync not found on remote"
        return 1
    fi
    
    echo ""
    log_success "Remote '$name' is ready for sync"
}

#--------------------------------------
# BUILD RSYNC COMMAND
#--------------------------------------
build_rsync_cmd() {
    local direction="$1"  # push or pull
    local name="$2"
    local dry_run="${3:-false}"
    
    local config_file
    config_file=$(find_remotes_config) || return 1
    
    local host path port
    host=$(jq -r ".remotes[\"$name\"].host" "$config_file")
    path=$(jq -r ".remotes[\"$name\"].path" "$config_file")
    port=$(jq -r ".remotes[\"$name\"].port // 22" "$config_file")
    
    # Get rsync options
    local rsync_opts
    rsync_opts=$(jq -r ".remotes[\"$name\"].rsync_opts // .defaults.rsync_opts // \"-avz --progress --delete\"" "$config_file")
    
    # Get excludes
    local excludes=()
    while IFS= read -r exclude; do
        [[ -n "$exclude" ]] && excludes+=("--exclude=$exclude")
    done < <(jq -r "(.remotes[\"$name\"].excludes // []) + (.defaults.excludes // []) | .[]" "$config_file" 2>/dev/null)
    
    # Build command
    local cmd="rsync $rsync_opts"
    
    # Add SSH options
    cmd+=" -e 'ssh -p $port'"
    
    # Add excludes
    for exclude in "${excludes[@]}"; do
        cmd+=" $exclude"
    done
    
    # Dry-run flag
    [[ "$dry_run" == "true" ]] && cmd+=" --dry-run"
    
    # Source and destination
    local vault_path="$VAULT_ROOT"
    vault_path="${vault_path/#\~/$HOME}"
    
    if [[ "$direction" == "push" ]]; then
        cmd+=" '${vault_path}/' '${host}:${path}/'"
    else
        cmd+=" '${host}:${path}/' '${vault_path}/'"
    fi
    
    echo "$cmd"
}

#--------------------------------------
# PUSH TO REMOTE
#--------------------------------------
remote_push() {
    local name="$1"
    local dry_run="${DRY_RUN:-false}"
    
    if [[ -z "$name" ]]; then
        log_error "Usage: remote push <name>"
        return 1
    fi
    
    # Check remote exists
    get_remote "$name" >/dev/null || return 1
    
    # Check local vault exists
    local vault_path="$VAULT_ROOT"
    vault_path="${vault_path/#\~/$HOME}"
    
    if [[ ! -d "$vault_path" ]]; then
        log_error "Local vault not found: $vault_path"
        return 1
    fi
    
    local config_file
    config_file=$(find_remotes_config)
    local host path
    host=$(jq -r ".remotes[\"$name\"].host" "$config_file")
    path=$(jq -r ".remotes[\"$name\"].path" "$config_file")
    
    if [[ "$dry_run" == "true" ]]; then
        log_info "[DRY-RUN] Preview of push to '$name':"
    else
        log_info "Pushing to '$name' ($host:$path)..."
    fi
    echo ""
    
    # Build and run rsync
    local cmd
    cmd=$(build_rsync_cmd "push" "$name" "$dry_run")
    
    log_debug "Command: $cmd"
    
    # Run rsync
    if eval "$cmd"; then
        echo ""
        if [[ "$dry_run" == "true" ]]; then
            log_success "[DRY-RUN] Push preview complete"
        else
            log_success "Push to '$name' complete"
        fi
    else
        log_error "Push failed"
        return 1
    fi
}

#--------------------------------------
# PULL FROM REMOTE
#--------------------------------------
remote_pull() {
    local name="$1"
    local dry_run="${DRY_RUN:-false}"
    
    if [[ -z "$name" ]]; then
        log_error "Usage: remote pull <name>"
        return 1
    fi
    
    # Check remote exists
    get_remote "$name" >/dev/null || return 1
    
    local config_file
    config_file=$(find_remotes_config)
    local host path
    host=$(jq -r ".remotes[\"$name\"].host" "$config_file")
    path=$(jq -r ".remotes[\"$name\"].path" "$config_file")
    
    # Check local vault directory exists (create if not)
    local vault_path="$VAULT_ROOT"
    vault_path="${vault_path/#\~/$HOME}"
    
    if [[ ! -d "$vault_path" ]] && [[ "$dry_run" != "true" ]]; then
        log_info "Creating local vault directory: $vault_path"
        mkdir -p "$vault_path"
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        log_info "[DRY-RUN] Preview of pull from '$name':"
    else
        log_info "Pulling from '$name' ($host:$path)..."
    fi
    echo ""
    
    # Build and run rsync
    local cmd
    cmd=$(build_rsync_cmd "pull" "$name" "$dry_run")
    
    log_debug "Command: $cmd"
    
    # Run rsync
    if eval "$cmd"; then
        echo ""
        if [[ "$dry_run" == "true" ]]; then
            log_success "[DRY-RUN] Pull preview complete"
        else
            log_success "Pull from '$name' complete"
        fi
    else
        log_error "Pull failed"
        return 1
    fi
}

#--------------------------------------
# SYNC STATUS
#--------------------------------------
remote_status() {
    local name="$1"
    
    if [[ -z "$name" ]]; then
        log_error "Usage: remote status <name>"
        return 1
    fi
    
    # Check remote exists
    get_remote "$name" >/dev/null || return 1
    
    local config_file
    config_file=$(find_remotes_config)
    local host path port
    host=$(jq -r ".remotes[\"$name\"].host" "$config_file")
    path=$(jq -r ".remotes[\"$name\"].path" "$config_file")
    port=$(jq -r ".remotes[\"$name\"].port // 22" "$config_file")
    
    local vault_path="$VAULT_ROOT"
    vault_path="${vault_path/#\~/$HOME}"
    
    log_info "Comparing local vs remote '$name'..."
    echo ""
    
    # Get local stats
    local local_files local_size
    if [[ -d "$vault_path" ]]; then
        local_files=$(find "$vault_path" -type f | wc -l)
        local_size=$(du -sh "$vault_path" 2>/dev/null | cut -f1)
    else
        local_files=0
        local_size="0"
    fi
    
    # Get remote stats
    local remote_files remote_size
    remote_files=$(ssh -o BatchMode=yes -p "$port" "$host" "find '$path' -type f 2>/dev/null | wc -l" 2>/dev/null || echo "?")
    remote_size=$(ssh -o BatchMode=yes -p "$port" "$host" "du -sh '$path' 2>/dev/null | cut -f1" 2>/dev/null || echo "?")
    
    echo "  Local vault:"
    echo "    Files: $local_files"
    echo "    Size:  $local_size"
    echo ""
    echo "  Remote '$name':"
    echo "    Files: $remote_files"
    echo "    Size:  $remote_size"
    echo ""
    
    # Quick diff preview
    log_info "Changes (dry-run):"
    echo ""
    
    # Use rsync dry-run to show what would change
    local cmd
    cmd=$(build_rsync_cmd "push" "$name" "true")
    cmd="${cmd/--progress/--stats}"
    
    eval "$cmd" 2>/dev/null | grep -E "^(Number|Total|deleting|>f)" | head -20 || true
}
