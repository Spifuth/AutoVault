#!/usr/bin/env bash
#===============================================================================
#
#  AUTOVAULT - Git-Sync.sh
#
#===============================================================================
#
#  DESCRIPTION:    Automatic git synchronization for vault changes
#                  Commit and push vault modifications automatically
#
#  COMMANDS:       status    - Show git sync status
#                  enable    - Enable auto-sync (via cron/systemd)
#                  disable   - Disable auto-sync
#                  now       - Sync now (commit + push)
#                  watch     - Watch for changes and sync (foreground)
#                  config    - Configure git-sync settings
#                  log       - Show sync history
#
#  USAGE:          ./cust-run-config.sh git-sync status
#                  ./cust-run-config.sh git-sync now
#                  ./cust-run-config.sh git-sync watch --interval 300
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
GIT_SYNC_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/autovault"
GIT_SYNC_CONFIG_FILE="$GIT_SYNC_CONFIG_DIR/git-sync.conf"
GIT_SYNC_LOG_FILE="$GIT_SYNC_CONFIG_DIR/git-sync.log"
DEFAULT_INTERVAL=300  # 5 minutes
DEFAULT_COMMIT_MSG="AutoVault: Auto-sync {{DATE}} {{TIME}}"
MAX_LOG_LINES=1000

#--------------------------------------
# LOAD CONFIG
#--------------------------------------
load_git_sync_config() {
    # Defaults
    GIT_SYNC_ENABLED=false
    GIT_SYNC_INTERVAL=$DEFAULT_INTERVAL
    GIT_SYNC_COMMIT_MSG="$DEFAULT_COMMIT_MSG"
    GIT_SYNC_PUSH=true
    GIT_SYNC_PULL_FIRST=true
    GIT_SYNC_BRANCH=""
    GIT_SYNC_REMOTE="origin"
    GIT_SYNC_INCLUDE_UNTRACKED=true
    GIT_SYNC_NOTIFY=true
    
    if [[ -f "$GIT_SYNC_CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$GIT_SYNC_CONFIG_FILE"
    fi
}

#--------------------------------------
# SAVE CONFIG
#--------------------------------------
save_git_sync_config() {
    mkdir -p "$GIT_SYNC_CONFIG_DIR"
    cat > "$GIT_SYNC_CONFIG_FILE" <<EOF
# AutoVault Git-Sync Configuration
# Generated on $(date)

GIT_SYNC_ENABLED=$GIT_SYNC_ENABLED
GIT_SYNC_INTERVAL=$GIT_SYNC_INTERVAL
GIT_SYNC_COMMIT_MSG="$GIT_SYNC_COMMIT_MSG"
GIT_SYNC_PUSH=$GIT_SYNC_PUSH
GIT_SYNC_PULL_FIRST=$GIT_SYNC_PULL_FIRST
GIT_SYNC_BRANCH="$GIT_SYNC_BRANCH"
GIT_SYNC_REMOTE="$GIT_SYNC_REMOTE"
GIT_SYNC_INCLUDE_UNTRACKED=$GIT_SYNC_INCLUDE_UNTRACKED
GIT_SYNC_NOTIFY=$GIT_SYNC_NOTIFY
EOF
    log_success "Configuration saved to $GIT_SYNC_CONFIG_FILE"
}

#--------------------------------------
# CHECK GIT REPOSITORY
#--------------------------------------
check_git_repo() {
    local vault_path
    vault_path=$(get_vault_path)
    
    if [[ -z "$vault_path" ]]; then
        log_error "No vault configured. Run 'autovault config' first."
        return 1
    fi
    
    if [[ ! -d "$vault_path/.git" ]]; then
        log_error "Vault is not a git repository: $vault_path"
        echo
        echo "Initialize git with:"
        echo "  cd \"$vault_path\""
        echo "  git init"
        echo "  git remote add origin <your-repo-url>"
        return 1
    fi
    
    echo "$vault_path"
}

#--------------------------------------
# GET CHANGES COUNT
#--------------------------------------
get_changes_count() {
    local vault_path="$1"
    local count=0
    
    cd "$vault_path"
    
    # Staged changes
    count=$((count + $(git diff --cached --numstat 2>/dev/null | wc -l)))
    
    # Unstaged changes
    count=$((count + $(git diff --numstat 2>/dev/null | wc -l)))
    
    # Untracked files
    if [[ "$GIT_SYNC_INCLUDE_UNTRACKED" == "true" ]]; then
        count=$((count + $(git ls-files --others --exclude-standard 2>/dev/null | wc -l)))
    fi
    
    echo "$count"
}

#--------------------------------------
# FORMAT COMMIT MESSAGE
#--------------------------------------
format_commit_message() {
    local msg="$GIT_SYNC_COMMIT_MSG"
    local date_str time_str
    
    date_str=$(date +%Y-%m-%d)
    time_str=$(date +%H:%M:%S)
    
    msg="${msg//\{\{DATE\}\}/$date_str}"
    msg="${msg//\{\{TIME\}\}/$time_str}"
    msg="${msg//\{\{USER\}\}/$USER}"
    msg="${msg//\{\{HOSTNAME\}\}/$(hostname)}"
    
    echo "$msg"
}

#--------------------------------------
# LOG SYNC EVENT
#--------------------------------------
log_sync_event() {
    local status="$1"
    local message="${2:-}"
    local timestamp
    
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    mkdir -p "$GIT_SYNC_CONFIG_DIR"
    
    echo "[$timestamp] [$status] $message" >> "$GIT_SYNC_LOG_FILE"
    
    # Rotate log if too large
    if [[ -f "$GIT_SYNC_LOG_FILE" ]]; then
        local lines
        lines=$(wc -l < "$GIT_SYNC_LOG_FILE")
        if [[ $lines -gt $MAX_LOG_LINES ]]; then
            tail -n $((MAX_LOG_LINES / 2)) "$GIT_SYNC_LOG_FILE" > "$GIT_SYNC_LOG_FILE.tmp"
            mv "$GIT_SYNC_LOG_FILE.tmp" "$GIT_SYNC_LOG_FILE"
        fi
    fi
}

#--------------------------------------
# SEND NOTIFICATION
#--------------------------------------
send_sync_notification() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"
    
    if [[ "$GIT_SYNC_NOTIFY" != "true" ]]; then
        return 0
    fi
    
    if command -v notify-send &>/dev/null; then
        notify-send -u "$urgency" "$title" "$message" 2>/dev/null || true
    elif command -v terminal-notifier &>/dev/null; then
        terminal-notifier -title "$title" -message "$message" 2>/dev/null || true
    fi
}

#--------------------------------------
# SYNC NOW
#--------------------------------------
do_sync() {
    local vault_path
    local changes_count
    local commit_msg
    local branch
    
    vault_path=$(check_git_repo) || return 1
    cd "$vault_path"
    
    load_git_sync_config
    
    # Get current branch
    branch="${GIT_SYNC_BRANCH:-$(git branch --show-current 2>/dev/null)}"
    if [[ -z "$branch" ]]; then
        log_error "Not on any branch. Please checkout a branch first."
        return 1
    fi
    
    log_info "Syncing vault: $vault_path"
    log_info "Branch: $branch"
    echo
    
    # Pull first if enabled
    if [[ "$GIT_SYNC_PULL_FIRST" == "true" ]]; then
        log_info "Pulling latest changes..."
        if git pull "$GIT_SYNC_REMOTE" "$branch" --rebase 2>/dev/null; then
            log_success "Pull completed"
        else
            log_warning "Pull failed or no remote configured"
        fi
    fi
    
    # Check for changes
    changes_count=$(get_changes_count "$vault_path")
    
    if [[ $changes_count -eq 0 ]]; then
        log_info "No changes to sync"
        log_sync_event "INFO" "No changes to sync"
        return 0
    fi
    
    log_info "Found $changes_count change(s)"
    
    # Stage all changes
    if [[ "$GIT_SYNC_INCLUDE_UNTRACKED" == "true" ]]; then
        git add -A
    else
        git add -u
    fi
    
    # Show what's being committed
    echo
    echo "Changes to be committed:"
    git diff --cached --stat
    echo
    
    # Commit
    commit_msg=$(format_commit_message)
    if git commit -m "$commit_msg"; then
        log_success "Committed: $commit_msg"
        log_sync_event "COMMIT" "$commit_msg ($changes_count files)"
    else
        log_error "Commit failed"
        log_sync_event "ERROR" "Commit failed"
        return 1
    fi
    
    # Push if enabled
    if [[ "$GIT_SYNC_PUSH" == "true" ]]; then
        log_info "Pushing to $GIT_SYNC_REMOTE/$branch..."
        if git push "$GIT_SYNC_REMOTE" "$branch"; then
            log_success "Push completed"
            log_sync_event "PUSH" "Pushed to $GIT_SYNC_REMOTE/$branch"
            send_sync_notification "AutoVault Sync" "✅ Synced $changes_count file(s) to $GIT_SYNC_REMOTE"
        else
            log_error "Push failed"
            log_sync_event "ERROR" "Push failed to $GIT_SYNC_REMOTE/$branch"
            send_sync_notification "AutoVault Sync" "❌ Push failed" "critical"
            return 1
        fi
    fi
    
    echo
    log_success "Sync completed successfully!"
    return 0
}

#--------------------------------------
# WATCH MODE
#--------------------------------------
do_watch() {
    local interval="${1:-$GIT_SYNC_INTERVAL}"
    local vault_path
    
    vault_path=$(check_git_repo) || return 1
    
    load_git_sync_config
    
    log_info "Watching vault for changes: $vault_path"
    log_info "Sync interval: ${interval}s"
    log_info "Press Ctrl+C to stop"
    echo
    
    # Trap to handle exit
    trap 'echo; log_info "Watch stopped"; exit 0' INT TERM
    
    while true; do
        local changes_count
        changes_count=$(get_changes_count "$vault_path")
        
        if [[ $changes_count -gt 0 ]]; then
            log_info "Detected $changes_count change(s), syncing..."
            do_sync || true
        else
            log_dim "$(date '+%H:%M:%S') - No changes"
        fi
        
        sleep "$interval"
    done
}

#--------------------------------------
# SHOW STATUS
#--------------------------------------
show_status() {
    local vault_path
    
    vault_path=$(check_git_repo) || return 1
    cd "$vault_path"
    
    load_git_sync_config
    
    echo
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║              AutoVault Git-Sync Status                 ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo
    
    # Vault info
    echo "📁 Vault:    $vault_path"
    echo "🌿 Branch:   $(git branch --show-current 2>/dev/null || echo 'detached')"
    echo "🔗 Remote:   $GIT_SYNC_REMOTE"
    echo
    
    # Config status
    echo "⚙️  Configuration:"
    if [[ "$GIT_SYNC_ENABLED" == "true" ]]; then
        echo "   Auto-sync:     ✅ Enabled"
    else
        echo "   Auto-sync:     ❌ Disabled"
    fi
    echo "   Interval:      ${GIT_SYNC_INTERVAL}s"
    echo "   Push:          $([ "$GIT_SYNC_PUSH" == "true" ] && echo "✅" || echo "❌")"
    echo "   Pull first:    $([ "$GIT_SYNC_PULL_FIRST" == "true" ] && echo "✅" || echo "❌")"
    echo "   Untracked:     $([ "$GIT_SYNC_INCLUDE_UNTRACKED" == "true" ] && echo "✅" || echo "❌")"
    echo "   Notifications: $([ "$GIT_SYNC_NOTIFY" == "true" ] && echo "✅" || echo "❌")"
    echo
    
    # Current changes
    local changes_count
    changes_count=$(get_changes_count "$vault_path")
    echo "📊 Current Status:"
    echo "   Pending changes: $changes_count"
    
    if [[ $changes_count -gt 0 ]]; then
        echo
        echo "   Modified files:"
        git status --short | head -10 | sed 's/^/      /'
        local total
        total=$(git status --short | wc -l)
        if [[ $total -gt 10 ]]; then
            echo "      ... and $((total - 10)) more"
        fi
    fi
    
    # Last sync
    echo
    if [[ -f "$GIT_SYNC_LOG_FILE" ]]; then
        echo "📜 Last sync events:"
        tail -5 "$GIT_SYNC_LOG_FILE" | sed 's/^/   /'
    fi
    
    echo
}

#--------------------------------------
# SHOW LOG
#--------------------------------------
show_log() {
    local lines="${1:-20}"
    
    if [[ ! -f "$GIT_SYNC_LOG_FILE" ]]; then
        log_info "No sync log found"
        return 0
    fi
    
    echo
    echo "Git-Sync Log (last $lines entries):"
    echo "─────────────────────────────────────────"
    tail -n "$lines" "$GIT_SYNC_LOG_FILE"
    echo
}

#--------------------------------------
# CONFIGURE
#--------------------------------------
do_config() {
    load_git_sync_config
    
    echo
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║            AutoVault Git-Sync Configuration            ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo
    
    # Sync interval
    read -rp "Sync interval in seconds [$GIT_SYNC_INTERVAL]: " input
    GIT_SYNC_INTERVAL="${input:-$GIT_SYNC_INTERVAL}"
    
    # Commit message
    echo
    echo "Commit message template (use {{DATE}}, {{TIME}}, {{USER}}, {{HOSTNAME}}):"
    read -rp "[$GIT_SYNC_COMMIT_MSG]: " input
    GIT_SYNC_COMMIT_MSG="${input:-$GIT_SYNC_COMMIT_MSG}"
    
    # Remote
    echo
    read -rp "Git remote name [$GIT_SYNC_REMOTE]: " input
    GIT_SYNC_REMOTE="${input:-$GIT_SYNC_REMOTE}"
    
    # Branch (empty = current)
    echo
    read -rp "Branch to sync (empty = current branch) [$GIT_SYNC_BRANCH]: " input
    GIT_SYNC_BRANCH="${input:-$GIT_SYNC_BRANCH}"
    
    # Options
    echo
    read -rp "Push after commit? (y/n) [$([ "$GIT_SYNC_PUSH" == "true" ] && echo "y" || echo "n")]: " input
    case "$input" in
        y|Y|yes) GIT_SYNC_PUSH=true ;;
        n|N|no) GIT_SYNC_PUSH=false ;;
    esac
    
    read -rp "Pull before commit? (y/n) [$([ "$GIT_SYNC_PULL_FIRST" == "true" ] && echo "y" || echo "n")]: " input
    case "$input" in
        y|Y|yes) GIT_SYNC_PULL_FIRST=true ;;
        n|N|no) GIT_SYNC_PULL_FIRST=false ;;
    esac
    
    read -rp "Include untracked files? (y/n) [$([ "$GIT_SYNC_INCLUDE_UNTRACKED" == "true" ] && echo "y" || echo "n")]: " input
    case "$input" in
        y|Y|yes) GIT_SYNC_INCLUDE_UNTRACKED=true ;;
        n|N|no) GIT_SYNC_INCLUDE_UNTRACKED=false ;;
    esac
    
    read -rp "Send desktop notifications? (y/n) [$([ "$GIT_SYNC_NOTIFY" == "true" ] && echo "y" || echo "n")]: " input
    case "$input" in
        y|Y|yes) GIT_SYNC_NOTIFY=true ;;
        n|N|no) GIT_SYNC_NOTIFY=false ;;
    esac
    
    echo
    save_git_sync_config
}

#--------------------------------------
# ENABLE AUTO-SYNC (Cron/Systemd)
#--------------------------------------
enable_auto_sync() {
    local vault_path
    local method="${1:-cron}"
    
    vault_path=$(check_git_repo) || return 1
    load_git_sync_config
    
    case "$method" in
        cron)
            enable_cron_sync "$vault_path"
            ;;
        systemd)
            enable_systemd_sync "$vault_path"
            ;;
        *)
            log_error "Unknown method: $method (use 'cron' or 'systemd')"
            return 1
            ;;
    esac
    
    GIT_SYNC_ENABLED=true
    save_git_sync_config
}

enable_cron_sync() {
    local vault_path="$1"
    local script_path
    local cron_interval
    
    script_path="$(cd "$SCRIPT_DIR/.." && pwd)/cust-run-config.sh"
    
    # Convert seconds to cron interval (minimum 1 minute)
    cron_interval=$((GIT_SYNC_INTERVAL / 60))
    [[ $cron_interval -lt 1 ]] && cron_interval=1
    
    # Create cron entry
    local cron_entry="*/$cron_interval * * * * cd \"$vault_path\" && \"$script_path\" git-sync now --quiet >> \"$GIT_SYNC_LOG_FILE\" 2>&1"
    
    # Check if already exists
    if crontab -l 2>/dev/null | grep -q "autovault.*git-sync"; then
        log_warning "Cron job already exists. Updating..."
        (crontab -l 2>/dev/null | grep -v "autovault.*git-sync"; echo "$cron_entry") | crontab -
    else
        (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
    fi
    
    log_success "Cron job installed (every $cron_interval minute(s))"
    echo "View with: crontab -l"
}

enable_systemd_sync() {
    local vault_path="$1"
    local service_dir="$HOME/.config/systemd/user"
    local script_path
    
    script_path="$(cd "$SCRIPT_DIR/.." && pwd)/cust-run-config.sh"
    
    mkdir -p "$service_dir"
    
    # Create service file
    cat > "$service_dir/autovault-sync.service" <<EOF
[Unit]
Description=AutoVault Git Sync
After=network.target

[Service]
Type=oneshot
WorkingDirectory=$vault_path
ExecStart=$script_path git-sync now --quiet
EOF
    
    # Create timer file
    cat > "$service_dir/autovault-sync.timer" <<EOF
[Unit]
Description=AutoVault Git Sync Timer

[Timer]
OnBootSec=60
OnUnitActiveSec=${GIT_SYNC_INTERVAL}s
Unit=autovault-sync.service

[Install]
WantedBy=timers.target
EOF
    
    # Enable and start
    systemctl --user daemon-reload
    systemctl --user enable autovault-sync.timer
    systemctl --user start autovault-sync.timer
    
    log_success "Systemd timer installed and started"
    echo "Check status: systemctl --user status autovault-sync.timer"
}

#--------------------------------------
# DISABLE AUTO-SYNC
#--------------------------------------
disable_auto_sync() {
    load_git_sync_config
    
    # Remove cron job
    if crontab -l 2>/dev/null | grep -q "autovault.*git-sync"; then
        crontab -l 2>/dev/null | grep -v "autovault.*git-sync" | crontab -
        log_success "Cron job removed"
    fi
    
    # Disable systemd timer
    if systemctl --user is-enabled autovault-sync.timer &>/dev/null; then
        systemctl --user stop autovault-sync.timer
        systemctl --user disable autovault-sync.timer
        log_success "Systemd timer disabled"
    fi
    
    GIT_SYNC_ENABLED=false
    save_git_sync_config
    
    log_success "Auto-sync disabled"
}

#--------------------------------------
# INIT GIT REPO
#--------------------------------------
init_git_repo() {
    local vault_path
    local remote_url="${1:-}"
    
    vault_path=$(get_vault_path)
    
    if [[ -z "$vault_path" ]]; then
        log_error "No vault configured. Run 'autovault config' first."
        return 1
    fi
    
    cd "$vault_path"
    
    if [[ -d ".git" ]]; then
        log_warning "Git repository already exists"
        return 0
    fi
    
    log_info "Initializing git repository in $vault_path"
    
    git init
    
    # Create .gitignore if not exists
    if [[ ! -f ".gitignore" ]]; then
        cat > ".gitignore" <<'EOF'
# AutoVault gitignore
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.obsidian/cache
.trash/
*.tmp
.DS_Store
Thumbs.db
EOF
        log_info "Created .gitignore"
    fi
    
    # Add remote if provided
    if [[ -n "$remote_url" ]]; then
        git remote add origin "$remote_url"
        log_success "Added remote: $remote_url"
    fi
    
    # Initial commit
    git add -A
    git commit -m "Initial commit: AutoVault setup"
    
    log_success "Git repository initialized"
    
    if [[ -z "$remote_url" ]]; then
        echo
        echo "Next steps:"
        echo "  1. Create a repository on GitHub/GitLab"
        echo "  2. Add remote: git remote add origin <url>"
        echo "  3. Push: git push -u origin main"
    fi
}

#--------------------------------------
# HELP
#--------------------------------------
show_help() {
    cat <<'EOF'
AutoVault Git-Sync - Automatic vault synchronization

USAGE:
    autovault git-sync <command> [options]

COMMANDS:
    status              Show git-sync status and pending changes
    now                 Sync now (commit + push)
    watch [--interval]  Watch for changes and sync continuously
    config              Configure git-sync settings interactively
    enable [method]     Enable auto-sync (cron or systemd)
    disable             Disable auto-sync
    log [lines]         Show sync history log
    init [remote-url]   Initialize vault as git repository

OPTIONS:
    --interval, -i      Sync interval in seconds (default: 300)
    --quiet, -q         Suppress output (for cron jobs)
    --help, -h          Show this help message

EXAMPLES:
    # Check current status
    autovault git-sync status

    # Sync immediately
    autovault git-sync now

    # Watch and sync every 2 minutes
    autovault git-sync watch --interval 120

    # Enable automatic sync via cron
    autovault git-sync enable cron

    # Initialize vault as git repo
    autovault git-sync init https://github.com/user/vault.git

CONFIGURATION:
    Config file: ~/.config/autovault/git-sync.conf
    Log file:    ~/.config/autovault/git-sync.log

COMMIT MESSAGE VARIABLES:
    {{DATE}}      Current date (YYYY-MM-DD)
    {{TIME}}      Current time (HH:MM:SS)
    {{USER}}      Current username
    {{HOSTNAME}}  Machine hostname

EOF
}

#--------------------------------------
# MAIN
#--------------------------------------
main() {
    local command="${1:-}"
    local quiet=false
    
    # Parse global options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --quiet|-q)
                quiet=true
                shift
                ;;
            --help|-h)
                show_help
                return 0
                ;;
            *)
                break
                ;;
        esac
    done
    
    command="${1:-status}"
    shift || true
    
    # Suppress output if quiet
    if [[ "$quiet" == "true" ]]; then
        exec > /dev/null 2>&1
    fi
    
    load_git_sync_config
    
    case "$command" in
        status)
            show_status
            ;;
        now|sync)
            do_sync
            ;;
        watch)
            local interval="$GIT_SYNC_INTERVAL"
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --interval|-i)
                        interval="$2"
                        shift 2
                        ;;
                    *)
                        shift
                        ;;
                esac
            done
            do_watch "$interval"
            ;;
        config|configure)
            do_config
            ;;
        enable)
            enable_auto_sync "${1:-cron}"
            ;;
        disable)
            disable_auto_sync
            ;;
        log|logs|history)
            show_log "${1:-20}"
            ;;
        init)
            init_git_repo "${1:-}"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Run 'autovault git-sync help' for usage"
            return 1
            ;;
    esac
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
