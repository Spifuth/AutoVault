#!/usr/bin/env bash
#===============================================================================
#
#  AUTOVAULT LIBRARY - logging.sh
#
#===============================================================================
#
#  DESCRIPTION:    Shared logging utilities for all AutoVault scripts.
#                  Provides colored, leveled logging with support for
#                  NO_COLOR environment variable.
#
#  LOG LEVELS:     0 = silent  (no output)
#                  1 = error   (errors only)
#                  2 = warn    (errors + warnings)
#                  3 = info    (default - errors, warnings, info)
#                  4 = debug   (verbose - all messages)
#
#  FUNCTIONS:      log_debug   - Debug messages (level 4)
#                  log_info    - Informational messages (level 3)
#                  log_warn    - Warning messages (level 2)
#                  log_error   - Error messages (level 1)
#                  log_success - Success messages (level 3, green)
#
#  USAGE:          source "$SCRIPT_DIR/lib/logging.sh"
#                  LOG_LEVEL=4 log_debug "Verbose message"
#                  log_info "Processing file..."
#                  log_error "Something went wrong!"
#
#  ENVIRONMENT:    LOG_LEVEL - Set logging verbosity (default: 3)
#                  NO_COLOR  - Disable colored output if set
#
#  REFERENCE:      https://no-color.org/
#
#===============================================================================

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
    # No colors
    BOLD=""
    RESET=""
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    CYAN=""
    GRAY=""
    DIM=""
    NC=""
  else
    # ANSI color codes
    # shellcheck disable=SC2034  # These are used by sourcing scripts
    BOLD="\033[1m"
    # shellcheck disable=SC2034
    RESET="\033[0m"
    # shellcheck disable=SC2034
    RED="\033[31m"
    # shellcheck disable=SC2034
    GREEN="\033[32m"
    # shellcheck disable=SC2034
    YELLOW="\033[33m"
    # shellcheck disable=SC2034
    BLUE="\033[34m"
    # shellcheck disable=SC2034
    CYAN="\033[36m"
    # shellcheck disable=SC2034
    GRAY="\033[90m"
    # shellcheck disable=SC2034
    DIM="\033[2m"
    # shellcheck disable=SC2034
    NC="\033[0m"
  fi
  
  # Legacy aliases (for backward compatibility)
  # shellcheck disable=SC2034
  COLOR_BLUE="$BLUE"
  # shellcheck disable=SC2034
  COLOR_YELLOW="$YELLOW"
  # shellcheck disable=SC2034
  COLOR_RED="$RED"
  # shellcheck disable=SC2034
  COLOR_GREEN="$GREEN"
  # shellcheck disable=SC2034
  COLOR_GRAY="$GRAY"
  # shellcheck disable=SC2034
  COLOR_RESET="$RESET"
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
