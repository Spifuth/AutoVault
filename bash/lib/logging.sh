#!/usr/bin/env bash
#
# logging.sh - Shared logging utilities for AutoVault
#
# Usage: source this file from any script that needs logging
#   source "$SCRIPT_DIR/lib/logging.sh"
#
# Provides:
#   - LOG_LEVEL control (0=silent, 1=error, 2=warn, 3=info, 4=debug)
#   - NO_COLOR support (https://no-color.org/)
#   - Colored log functions: log_debug, log_info, log_warn, log_error, log_success
#

# Prevent multiple sourcing
[[ -n "${_LOGGING_SH_LOADED:-}" ]] && return 0
_LOGGING_SH_LOADED=1

#--------------------------------------
# GLOBAL FLAGS
#--------------------------------------
# Log levels: 0=silent, 1=error, 2=warn, 3=info (default), 4=debug
LOG_LEVEL="${LOG_LEVEL:-3}"

# NO_COLOR environment variable support (https://no-color.org/)
NO_COLOR="${NO_COLOR:-}"

#--------------------------------------
# COLOR SETUP
#--------------------------------------
setup_colors() {
  if [[ -n "$NO_COLOR" ]] || [[ ! -t 2 ]]; then
    COLOR_BLUE=""
    COLOR_YELLOW=""
    COLOR_RED=""
    COLOR_GREEN=""
    COLOR_GRAY=""
    COLOR_RESET=""
    # Short aliases for scripts
    BOLD=""
    RESET=""
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
  else
    COLOR_BLUE="\033[34m"
    COLOR_YELLOW="\033[33m"
    COLOR_RED="\033[31m"
    COLOR_GREEN="\033[32m"
    COLOR_GRAY="\033[90m"
    COLOR_RESET="\033[0m"
    # Short aliases for scripts
    BOLD="\033[1m"
    RESET="\033[0m"
    RED="\033[31m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    BLUE="\033[34m"
  fi
}

# Initialize colors (may be re-called after parsing --no-color flag)
setup_colors

#--------------------------------------
# LOG FUNCTIONS (colored, respects LOG_LEVEL)
#--------------------------------------
log_debug() {
  [[ "$LOG_LEVEL" -ge 4 ]] && printf "%b[DEBUG]%b %s\n" "$COLOR_GRAY" "$COLOR_RESET" "$1" >&2
  return 0
}

log_info() {
  [[ "$LOG_LEVEL" -ge 3 ]] && printf "%b[INFO ]%b %s\n" "$COLOR_BLUE" "$COLOR_RESET" "$1" >&2
  return 0
}

log_warn() {
  [[ "$LOG_LEVEL" -ge 2 ]] && printf "%b[WARN ]%b %s\n" "$COLOR_YELLOW" "$COLOR_RESET" "$1" >&2
  return 0
}

log_error() {
  [[ "$LOG_LEVEL" -ge 1 ]] && printf "%b[ERROR]%b %s\n" "$COLOR_RED" "$COLOR_RESET" "$1" >&2
  return 0
}

log_success() {
  [[ "$LOG_LEVEL" -ge 3 ]] && printf "%b[OK   ]%b %s\n" "$COLOR_GREEN" "$COLOR_RESET" "$1" >&2
  return 0
}
