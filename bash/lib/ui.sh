#!/usr/bin/env bash
#===============================================================================
#
#  AUTOVAULT LIBRARY - ui.sh
#
#===============================================================================
#
#  DESCRIPTION:    Enhanced UI utilities for AutoVault CLI.
#                  Provides progress bars, spinners, notifications,
#                  color themes, and interactive menus.
#
#  FUNCTIONS:      Theme & Colors
#                  - set_theme()         Set color theme (dark/light/auto)
#                  - get_theme()         Get current theme
#
#                  Progress Indicators
#                  - progress_bar()      Display progress bar
#                  - spinner_start()     Start spinner animation
#                  - spinner_stop()      Stop spinner animation
#
#                  Interactive
#                  - select_menu()       Interactive selection menu (fzf/fallback)
#                  - confirm()           Yes/No confirmation prompt
#                  - prompt_input()      Input prompt with validation
#
#                  Notifications
#                  - notify()            Desktop notification
#                  - notify_success()    Success notification
#                  - notify_error()      Error notification
#
#  USAGE:          source "$LIB_DIR/ui.sh"
#                  progress_bar 50 100 "Processing..."
#                  spinner_start "Loading..."
#                  notify "Operation complete"
#
#  ENVIRONMENT:    AUTOVAULT_THEME  - Color theme (dark/light/auto)
#                  AUTOVAULT_NOTIFY - Enable notifications (true/false)
#                  NO_COLOR         - Disable all colors
#
#===============================================================================

# Prevent multiple sourcing
[[ -n "${_UI_SH_LOADED:-}" ]] && return 0
_UI_SH_LOADED=1

#--------------------------------------
# THEME CONFIGURATION
#--------------------------------------
# Theme: dark (default), light, auto
AUTOVAULT_THEME="${AUTOVAULT_THEME:-dark}"

# Notifications enabled by default
AUTOVAULT_NOTIFY="${AUTOVAULT_NOTIFY:-true}"

# Spinner PID (for background spinner)
_SPINNER_PID=""

#--------------------------------------
# THEME COLORS
#--------------------------------------
declare -A THEME_DARK=(
  [primary]="\033[36m"      # Cyan
  [secondary]="\033[34m"    # Blue
  [success]="\033[32m"      # Green
  [warning]="\033[33m"      # Yellow
  [error]="\033[31m"        # Red
  [muted]="\033[90m"        # Gray
  [bold]="\033[1m"
  [dim]="\033[2m"
  [reset]="\033[0m"
  [bar_fill]="█"
  [bar_empty]="░"
)

declare -A THEME_LIGHT=(
  [primary]="\033[34m"      # Blue (darker for light bg)
  [secondary]="\033[35m"    # Magenta
  [success]="\033[32m"      # Green
  [warning]="\033[33m"      # Yellow
  [error]="\033[31m"        # Red
  [muted]="\033[37m"        # Light gray
  [bold]="\033[1m"
  [dim]="\033[2m"
  [reset]="\033[0m"
  [bar_fill]="▓"
  [bar_empty]="░"
)

# Current theme reference
declare -A THEME

#--------------------------------------
# THEME FUNCTIONS
#--------------------------------------

# Detect terminal background (heuristic)
_detect_theme() {
  # Check common environment indicators
  if [[ "${COLORFGBG:-}" == *";15" ]] || [[ "${COLORFGBG:-}" == *";7" ]]; then
    echo "light"
  elif [[ "${TERM_PROGRAM:-}" == "Apple_Terminal" ]]; then
    # macOS Terminal default is light
    echo "light"
  else
    echo "dark"
  fi
}

# Set the color theme
set_theme() {
  local theme="${1:-auto}"
  
  case "$theme" in
    light)
      for key in "${!THEME_LIGHT[@]}"; do
        THEME[$key]="${THEME_LIGHT[$key]}"
      done
      AUTOVAULT_THEME="light"
      ;;
    dark)
      for key in "${!THEME_DARK[@]}"; do
        THEME[$key]="${THEME_DARK[$key]}"
      done
      AUTOVAULT_THEME="dark"
      ;;
    auto)
      local detected
      detected=$(_detect_theme)
      set_theme "$detected"
      ;;
    *)
      # Default to dark
      set_theme "dark"
      ;;
  esac
  
  # Respect NO_COLOR
  if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
    for key in "${!THEME[@]}"; do
      [[ "$key" != "bar_fill" && "$key" != "bar_empty" ]] && THEME[$key]=""
    done
  fi
}

# Get current theme name
get_theme() {
  echo "$AUTOVAULT_THEME"
}

# Initialize theme
set_theme "$AUTOVAULT_THEME"

#--------------------------------------
# PROGRESS BAR
#--------------------------------------

# Display a progress bar
# Usage: progress_bar <current> <total> [label] [width]
progress_bar() {
  local current="${1:-0}"
  local total="${2:-100}"
  local label="${3:-}"
  local width="${4:-40}"
  
  # Calculate percentage
  local percent=0
  if [[ "$total" -gt 0 ]]; then
    percent=$((current * 100 / total))
  fi
  
  # Calculate filled width
  local filled=$((width * current / total))
  local empty=$((width - filled))
  
  # Build bar
  local bar=""
  local i
  for ((i=0; i<filled; i++)); do
    bar+="${THEME[bar_fill]}"
  done
  for ((i=0; i<empty; i++)); do
    bar+="${THEME[bar_empty]}"
  done
  
  # Print (carriage return to overwrite)
  printf "\r${THEME[primary]}%s${THEME[reset]} [${THEME[success]}%s${THEME[muted]}%s${THEME[reset]}] %3d%%" \
    "${label:0:20}" \
    "${bar:0:$filled}" \
    "${bar:$filled}" \
    "$percent"
  
  # Newline if complete
  if [[ "$current" -ge "$total" ]]; then
    echo ""
  fi
}

# Progress bar with items count
# Usage: progress_bar_items <current> <total> <label>
progress_bar_items() {
  local current="$1"
  local total="$2"
  local label="$3"
  
  progress_bar "$current" "$total" "$label"
  printf " (%d/%d)" "$current" "$total"
  
  if [[ "$current" -ge "$total" ]]; then
    echo ""
  fi
}

#--------------------------------------
# SPINNER
#--------------------------------------

# Spinner characters
_SPINNER_CHARS="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
# Alternative: "⣾⣽⣻⢿⡿⣟⣯⣷" or "|/-\" for basic terminals

# Background spinner function
_spinner_loop() {
  local message="$1"
  local i=0
  local len=${#_SPINNER_CHARS}
  
  while true; do
    local char="${_SPINNER_CHARS:$i:1}"
    printf "\r${THEME[primary]}%s${THEME[reset]} %s" "$char" "$message"
    i=$(( (i + 1) % len ))
    sleep 0.1
  done
}

# Start spinner in background
# Usage: spinner_start "Loading..."
spinner_start() {
  local message="${1:-Loading...}"
  
  # Don't start if not a terminal
  [[ ! -t 1 ]] && return 0
  
  # Stop any existing spinner
  spinner_stop 2>/dev/null
  
  # Start background spinner
  _spinner_loop "$message" &
  _SPINNER_PID=$!
  disown "$_SPINNER_PID" 2>/dev/null
}

# Stop the spinner
# Usage: spinner_stop [final_message]
spinner_stop() {
  local message="${1:-}"
  
  if [[ -n "$_SPINNER_PID" ]]; then
    kill "$_SPINNER_PID" 2>/dev/null
    wait "$_SPINNER_PID" 2>/dev/null
    _SPINNER_PID=""
  fi
  
  # Clear line
  printf "\r\033[K"
  
  # Print final message if provided
  if [[ -n "$message" ]]; then
    echo -e "$message"
  fi
}

# Simple inline spinner (blocking)
# Usage: command | spinner_inline "Processing..."
spinner_inline() {
  local message="${1:-Processing...}"
  local i=0
  local len=${#_SPINNER_CHARS}
  
  while IFS= read -r line; do
    local char="${_SPINNER_CHARS:$i:1}"
    printf "\r${THEME[primary]}%s${THEME[reset]} %s" "$char" "$message"
    i=$(( (i + 1) % len ))
  done
  
  printf "\r\033[K"
}

#--------------------------------------
# INTERACTIVE MENUS
#--------------------------------------

# Check if fzf is available
_has_fzf() {
  command -v fzf &>/dev/null
}

# Interactive selection menu
# Usage: result=$(select_menu "Choose option:" "option1" "option2" "option3")
select_menu() {
  local prompt="$1"
  shift
  local options=("$@")
  
  if _has_fzf && [[ -t 0 ]]; then
    # Use fzf if available
    printf '%s\n' "${options[@]}" | fzf --prompt="$prompt " --height=10 --reverse
  else
    # Fallback to select
    echo -e "${THEME[primary]}$prompt${THEME[reset]}" >&2
    
    local PS3="Enter number: "
    local choice
    select choice in "${options[@]}"; do
      if [[ -n "$choice" ]]; then
        echo "$choice"
        return 0
      fi
    done
  fi
}

# Multi-select menu (fzf only, fallback to single select)
# Usage: results=$(multi_select_menu "Select items:" "item1" "item2" "item3")
multi_select_menu() {
  local prompt="$1"
  shift
  local options=("$@")
  
  if _has_fzf && [[ -t 0 ]]; then
    printf '%s\n' "${options[@]}" | fzf --prompt="$prompt " --multi --height=15 --reverse
  else
    # Fallback to single select
    select_menu "$prompt" "${options[@]}"
  fi
}

# Yes/No confirmation
# Usage: if confirm "Proceed?"; then ...; fi
confirm() {
  local prompt="${1:-Continue?}"
  local default="${2:-n}"
  
  local yn_prompt
  if [[ "$default" == "y" ]]; then
    yn_prompt="[Y/n]"
  else
    yn_prompt="[y/N]"
  fi
  
  echo -en "${THEME[warning]}$prompt${THEME[reset]} $yn_prompt "
  
  local answer
  read -r answer
  answer="${answer:-$default}"
  
  [[ "$answer" =~ ^[Yy] ]]
}

# Input prompt with optional validation
# Usage: value=$(prompt_input "Enter name:" "default" "^[a-zA-Z]+$")
prompt_input() {
  local prompt="$1"
  local default="${2:-}"
  local pattern="${3:-}"
  
  local value
  while true; do
    echo -en "${THEME[primary]}$prompt${THEME[reset]} "
    [[ -n "$default" ]] && echo -en "${THEME[muted]}[$default]${THEME[reset]} "
    
    read -r value
    value="${value:-$default}"
    
    # Validate if pattern provided
    if [[ -n "$pattern" ]]; then
      if [[ "$value" =~ $pattern ]]; then
        break
      else
        echo -e "${THEME[error]}Invalid input. Please try again.${THEME[reset]}" >&2
      fi
    else
      break
    fi
  done
  
  echo "$value"
}

#--------------------------------------
# NOTIFICATIONS
#--------------------------------------

# Check for notification command
_get_notify_cmd() {
  if command -v notify-send &>/dev/null; then
    echo "notify-send"
  elif command -v terminal-notifier &>/dev/null; then
    echo "terminal-notifier"
  elif command -v osascript &>/dev/null; then
    echo "osascript"
  else
    echo ""
  fi
}

# Send desktop notification
# Usage: notify "Title" "Message" [urgency]
notify() {
  local title="${1:-AutoVault}"
  local message="${2:-}"
  local urgency="${3:-normal}"  # low, normal, critical
  
  # Skip if notifications disabled
  [[ "$AUTOVAULT_NOTIFY" != "true" ]] && return 0
  
  local cmd
  cmd=$(_get_notify_cmd)
  
  case "$cmd" in
    notify-send)
      notify-send -u "$urgency" "$title" "$message" 2>/dev/null
      ;;
    terminal-notifier)
      terminal-notifier -title "$title" -message "$message" 2>/dev/null
      ;;
    osascript)
      osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null
      ;;
    *)
      # No notification system available - silent fail
      return 0
      ;;
  esac
}

# Success notification
notify_success() {
  local message="${1:-Operation completed successfully}"
  notify "✅ AutoVault" "$message" "normal"
}

# Error notification
notify_error() {
  local message="${1:-An error occurred}"
  notify "❌ AutoVault" "$message" "critical"
}

# Warning notification
notify_warning() {
  local message="${1:-Warning}"
  notify "⚠️ AutoVault" "$message" "normal"
}

#--------------------------------------
# BOXES & FORMATTING
#--------------------------------------

# Print a styled box
# Usage: print_box "Title" "Content line 1" "Content line 2"
print_box() {
  local title="$1"
  shift
  local lines=("$@")
  local width=60
  
  # Top border
  echo -e "${THEME[primary]}╔$(printf '═%.0s' $(seq 1 $width))╗${THEME[reset]}"
  
  # Title
  if [[ -n "$title" ]]; then
    local padded_title
    padded_title=$(printf "%-${width}s" "  $title")
    echo -e "${THEME[primary]}║${THEME[reset]}${THEME[bold]}${padded_title:0:$width}${THEME[reset]}${THEME[primary]}║${THEME[reset]}"
    echo -e "${THEME[primary]}╠$(printf '═%.0s' $(seq 1 $width))╣${THEME[reset]}"
  fi
  
  # Content
  for line in "${lines[@]}"; do
    local padded_line
    padded_line=$(printf "%-${width}s" "  $line")
    echo -e "${THEME[primary]}║${THEME[reset]}${padded_line:0:$width}${THEME[primary]}║${THEME[reset]}"
  done
  
  # Bottom border
  echo -e "${THEME[primary]}╚$(printf '═%.0s' $(seq 1 $width))╝${THEME[reset]}"
}

# Print a section header
# Usage: print_section "Section Title"
print_section() {
  local title="$1"
  local width="${2:-50}"
  
  echo ""
  echo -e "${THEME[bold]}$title${THEME[reset]}"
  echo -e "${THEME[muted]}$(printf '─%.0s' $(seq 1 $width))${THEME[reset]}"
}

# Print key-value pair
# Usage: print_kv "Key" "Value"
print_kv() {
  local key="$1"
  local value="$2"
  local key_width="${3:-15}"
  
  printf "${THEME[muted]}%-${key_width}s${THEME[reset]} %s\n" "$key:" "$value"
}

#--------------------------------------
# TABLE FORMATTING
#--------------------------------------

# Print a simple table row
# Usage: table_row "col1" "col2" "col3"
table_row() {
  local cols=("$@")
  local output=""
  
  for col in "${cols[@]}"; do
    output+="$(printf "%-20s" "$col")"
  done
  
  echo "$output"
}

# Print table header
# Usage: table_header "Col1" "Col2" "Col3"
table_header() {
  echo -e "${THEME[bold]}$(table_row "$@")${THEME[reset]}"
  echo -e "${THEME[muted]}$(printf '─%.0s' {1..60})${THEME[reset]}"
}

#--------------------------------------
# CLEANUP
#--------------------------------------

# Cleanup function (call on script exit)
ui_cleanup() {
  spinner_stop
}

# Register cleanup
trap ui_cleanup EXIT
