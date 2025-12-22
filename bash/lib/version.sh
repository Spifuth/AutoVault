#!/usr/bin/env bash
#===============================================================================
#
#  AUTOVAULT LIBRARY - version.sh
#
#===============================================================================
#
#  DESCRIPTION:    Version management and update checking for AutoVault.
#                  Provides version display and GitHub release checking.
#
#  FUNCTIONS:      show_version()       - Display current version
#                  check_for_updates()  - Check GitHub for newer releases
#                  compare_versions()   - Compare semantic versions
#
#  USAGE:          source "$LIB_DIR/version.sh"
#                  show_version
#                  check_for_updates
#
#  ENVIRONMENT:    AUTOVAULT_SKIP_UPDATE_CHECK - Skip update check
#                  GITHUB_TOKEN                - For API rate limits
#
#===============================================================================

# Prevent multiple sourcing
[[ -n "${_VERSION_SH_LOADED:-}" ]] && return 0
_VERSION_SH_LOADED=1

#--------------------------------------
# VERSION INFO
#--------------------------------------
AUTOVAULT_VERSION="2.3.0"
AUTOVAULT_REPO="Spifuth/AutoVault"
AUTOVAULT_RELEASE_URL="https://api.github.com/repos/${AUTOVAULT_REPO}/releases/latest"
AUTOVAULT_REPO_URL="https://github.com/${AUTOVAULT_REPO}"

#--------------------------------------
# SHOW VERSION
#--------------------------------------
show_version() {
    local script_name
    script_name="$(basename "${BASH_SOURCE[2]:-$0}")"
    
    cat <<EOF
$(_h_cyan)AutoVault$(_h_reset) version $(_h_bold)${AUTOVAULT_VERSION}$(_h_reset)

$(_h_dim)Obsidian Vault Structure Manager$(_h_reset)
$(_h_dim)Repository: ${AUTOVAULT_REPO_URL}$(_h_reset)

$(_h_bold)Build Information:$(_h_reset)
  Version:    ${AUTOVAULT_VERSION}
  Shell:      bash ${BASH_VERSION}
  Platform:   $(uname -s) $(uname -m)
  
$(_h_bold)Dependencies:$(_h_reset)
  jq:         $(jq --version 2>/dev/null || echo "not installed")
  python3:    $(python3 --version 2>/dev/null | cut -d' ' -f2 || echo "not installed")
  git:        $(git --version 2>/dev/null | cut -d' ' -f3 || echo "not installed")
EOF

    # Check for updates unless disabled
    if [[ -z "${AUTOVAULT_SKIP_UPDATE_CHECK:-}" ]]; then
        echo ""
        check_for_updates
    fi
}

#--------------------------------------
# CHECK FOR UPDATES
#--------------------------------------
check_for_updates() {
    # Skip if no curl/wget available
    if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
        return 0
    fi
    
    # Skip in CI environments
    if [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]]; then
        return 0
    fi
    
    echo "$(_h_dim)Checking for updates...$(_h_reset)"
    
    local latest_version
    latest_version=$(get_latest_version)
    
    if [[ -z "$latest_version" ]]; then
        echo "$(_h_dim)Unable to check for updates (network error or rate limited)$(_h_reset)"
        return 0
    fi
    
    if version_gt "$latest_version" "$AUTOVAULT_VERSION"; then
        echo ""
        echo "$(_h_yellow)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(_h_reset)"
        echo "$(_h_yellow)  🎉 New version available!$(_h_reset)"
        echo "$(_h_yellow)     Current: ${AUTOVAULT_VERSION}  →  Latest: ${latest_version}$(_h_reset)"
        echo ""
        echo "$(_h_yellow)  To update:$(_h_reset)"
        echo "$(_h_dim)     cd $(dirname "${BASH_SOURCE[0]}")/../..$(_h_reset)"
        echo "$(_h_dim)     git pull origin main$(_h_reset)"
        echo ""
        echo "$(_h_dim)  Or visit: ${AUTOVAULT_REPO_URL}/releases/latest$(_h_reset)"
        echo "$(_h_yellow)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(_h_reset)"
    else
        echo "$(_h_green)✓$(_h_reset) You're running the latest version ($AUTOVAULT_VERSION)"
    fi
}

#--------------------------------------
# GET LATEST VERSION FROM GITHUB
#--------------------------------------
get_latest_version() {
    local response
    local auth_header=""
    
    # Use GitHub token if available (higher rate limit)
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        auth_header="-H Authorization: token ${GITHUB_TOKEN}"
    fi
    
    # Try curl first, then wget
    if command -v curl &>/dev/null; then
        response=$(curl -sf --max-time 5 $auth_header "$AUTOVAULT_RELEASE_URL" 2>/dev/null)
    elif command -v wget &>/dev/null; then
        response=$(wget -qO- --timeout=5 "$AUTOVAULT_RELEASE_URL" 2>/dev/null)
    else
        return 1
    fi
    
    # Parse version from response (remove 'v' prefix if present)
    if [[ -n "$response" ]]; then
        echo "$response" | grep -oP '"tag_name":\s*"v?\K[^"]+' | head -1
    fi
}

#--------------------------------------
# VERSION COMPARISON
#--------------------------------------
# Returns 0 if version1 > version2
version_gt() {
    local v1="$1"
    local v2="$2"
    
    # Remove 'v' prefix if present
    v1="${v1#v}"
    v2="${v2#v}"
    
    # Compare using sort -V
    if [[ "$(printf '%s\n%s' "$v1" "$v2" | sort -V | tail -n1)" == "$v1" ]] && [[ "$v1" != "$v2" ]]; then
        return 0
    fi
    return 1
}

#--------------------------------------
# GET GIT INFO (if in git repo)
#--------------------------------------
get_git_info() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    
    if [[ -d "$script_dir/.git" ]]; then
        local branch commit date
        branch=$(git -C "$script_dir" branch --show-current 2>/dev/null)
        commit=$(git -C "$script_dir" rev-parse --short HEAD 2>/dev/null)
        date=$(git -C "$script_dir" log -1 --format=%cd --date=short 2>/dev/null)
        
        if [[ -n "$commit" ]]; then
            echo "  Git Branch: ${branch:-detached}"
            echo "  Git Commit: ${commit} (${date})"
        fi
    fi
}
