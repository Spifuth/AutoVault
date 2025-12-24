#!/usr/bin/env bash
#===============================================================================
#
#  SCRIPT NAME:    Configure-Theme.sh
#  DESCRIPTION:    Configure AutoVault color theme and UI preferences
#
#  USAGE:          ./Configure-Theme.sh [subcommand] [options]
#
#  SUBCOMMANDS:    status      Show current theme settings
#                  set <name>  Set theme (dark/light/auto)
#                  preview     Preview all themes
#                  config      Interactive configuration
#
#  AUTHOR:         AutoVault Project
#  VERSION:        2.8.0
#
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/ui.sh"

# Config file for theme preferences
THEME_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/autovault/theme.conf"

#--------------------------------------
# USAGE
#--------------------------------------
usage() {
  cat << EOF
${THEME[bold]}USAGE${THEME[reset]}
    $(basename "$0") [SUBCOMMAND] [OPTIONS]

${THEME[bold]}SUBCOMMANDS${THEME[reset]}
    status          Show current theme settings (default)
    set <theme>     Set theme (dark, light, auto)
    preview         Preview all available themes
    config          Interactive theme configuration
    reset           Reset to default settings

${THEME[bold]}THEMES${THEME[reset]}
    dark    Dark terminal background (default)
    light   Light terminal background
    auto    Auto-detect based on terminal

${THEME[bold]}ENVIRONMENT${THEME[reset]}
    AUTOVAULT_THEME     Override theme (dark/light/auto)
    AUTOVAULT_NOTIFY    Enable notifications (true/false)
    NO_COLOR            Disable all colors

${THEME[bold]}EXAMPLES${THEME[reset]}
    $(basename "$0")                # Show current settings
    $(basename "$0") set light      # Use light theme
    $(basename "$0") preview        # Preview all themes
    $(basename "$0") config         # Interactive setup

${THEME[bold]}CONFIGURATION FILE${THEME[reset]}
    $THEME_CONFIG

EOF
}

#--------------------------------------
# LOAD/SAVE CONFIG
#--------------------------------------
load_theme_config() {
  if [[ -f "$THEME_CONFIG" ]]; then
    # shellcheck source=/dev/null
    source "$THEME_CONFIG"
  fi
}

save_theme_config() {
  local theme="$1"
  local notify="${2:-true}"
  
  mkdir -p "$(dirname "$THEME_CONFIG")"
  
  cat > "$THEME_CONFIG" << EOF
# AutoVault Theme Configuration
# Generated on $(date)

# Color theme: dark, light, auto
AUTOVAULT_THEME="$theme"

# Desktop notifications: true, false
AUTOVAULT_NOTIFY="$notify"
EOF
  
  echo -e "${THEME[success]}✓ Configuration saved to $THEME_CONFIG${THEME[reset]}"
}

#--------------------------------------
# SHOW STATUS
#--------------------------------------
show_status() {
  print_section "Theme Settings"
  
  echo ""
  print_kv "Current theme" "$(get_theme)"
  print_kv "Notifications" "$AUTOVAULT_NOTIFY"
  print_kv "NO_COLOR" "${NO_COLOR:-not set}"
  print_kv "Config file" "$THEME_CONFIG"
  
  echo ""
  if [[ -f "$THEME_CONFIG" ]]; then
    echo -e "${THEME[muted]}Config file exists${THEME[reset]}"
  else
    echo -e "${THEME[muted]}Config file not created (using defaults)${THEME[reset]}"
  fi
  
  echo ""
  echo "Current palette:"
  echo -e "  ${THEME[primary]}■${THEME[reset]} Primary  ${THEME[secondary]}■${THEME[reset]} Secondary  ${THEME[success]}■${THEME[reset]} Success  ${THEME[warning]}■${THEME[reset]} Warning  ${THEME[error]}■${THEME[reset]} Error  ${THEME[muted]}■${THEME[reset]} Muted"
}

#--------------------------------------
# SET THEME
#--------------------------------------
set_theme_cmd() {
  local theme="$1"
  
  case "$theme" in
    dark|light|auto)
      save_theme_config "$theme" "$AUTOVAULT_NOTIFY"
      set_theme "$theme"
      echo ""
      echo -e "${THEME[success]}✓ Theme set to: $theme${THEME[reset]}"
      echo ""
      echo "Preview:"
      echo -e "  ${THEME[primary]}■${THEME[reset]} Primary  ${THEME[secondary]}■${THEME[reset]} Secondary  ${THEME[success]}■${THEME[reset]} Success  ${THEME[warning]}■${THEME[reset]} Warning  ${THEME[error]}■${THEME[reset]} Error"
      ;;
    *)
      log_error "Invalid theme: $theme"
      echo "Available themes: dark, light, auto"
      exit 1
      ;;
  esac
}

#--------------------------------------
# PREVIEW THEMES
#--------------------------------------
preview_themes() {
  print_section "Theme Preview"
  echo ""
  
  for theme_name in dark light; do
    echo -e "${THEME[bold]}$theme_name theme:${THEME[reset]}"
    set_theme "$theme_name"
    
    echo -e "  Colors: ${THEME[primary]}Primary${THEME[reset]} | ${THEME[secondary]}Secondary${THEME[reset]} | ${THEME[success]}Success${THEME[reset]} | ${THEME[warning]}Warning${THEME[reset]} | ${THEME[error]}Error${THEME[reset]} | ${THEME[muted]}Muted${THEME[reset]}"
    echo -e "  Progress: ${THEME[success]}${THEME[bar_fill]}${THEME[bar_fill]}${THEME[bar_fill]}${THEME[bar_fill]}${THEME[bar_fill]}${THEME[reset]}${THEME[muted]}${THEME[bar_empty]}${THEME[bar_empty]}${THEME[bar_empty]}${THEME[bar_empty]}${THEME[bar_empty]}${THEME[reset]} 50%"
    echo -e "  Box chars: ${THEME[primary]}╔═╗ ║ ╚═╝${THEME[reset]}"
    echo ""
  done
  
  # Restore current theme
  load_theme_config
  set_theme "${AUTOVAULT_THEME:-dark}"
}

#--------------------------------------
# INTERACTIVE CONFIG
#--------------------------------------
interactive_config() {
  echo ""
  echo -e "${THEME[primary]}╔══════════════════════════════════════════════════════════════╗${THEME[reset]}"
  echo -e "${THEME[primary]}║${THEME[reset]}                                                              ${THEME[primary]}║${THEME[reset]}"
  echo -e "${THEME[primary]}║${THEME[reset]}    ${THEME[bold]}🎨 Theme Configuration${THEME[reset]}                                 ${THEME[primary]}║${THEME[reset]}"
  echo -e "${THEME[primary]}║${THEME[reset]}                                                              ${THEME[primary]}║${THEME[reset]}"
  echo -e "${THEME[primary]}╚══════════════════════════════════════════════════════════════╝${THEME[reset]}"
  echo ""
  
  # Theme selection
  echo -e "${THEME[bold]}Select color theme:${THEME[reset]}"
  echo ""
  
  local themes=("dark" "light" "auto")
  local i=1
  for t in "${themes[@]}"; do
    local marker=" "
    [[ "$t" == "${AUTOVAULT_THEME:-dark}" ]] && marker="*"
    echo "  $i) $t $marker"
    ((i++))
  done
  echo ""
  
  local choice
  read -rp "Enter choice [1-3]: " choice
  
  local selected_theme
  case "$choice" in
    1) selected_theme="dark" ;;
    2) selected_theme="light" ;;
    3) selected_theme="auto" ;;
    *) selected_theme="${AUTOVAULT_THEME:-dark}" ;;
  esac
  
  echo ""
  
  # Notifications
  echo -e "${THEME[bold]}Enable desktop notifications?${THEME[reset]}"
  local notify_enabled
  if confirm "Enable notifications?" "y"; then
    notify_enabled="true"
  else
    notify_enabled="false"
  fi
  
  echo ""
  
  # Save
  save_theme_config "$selected_theme" "$notify_enabled"
  
  # Apply
  set_theme "$selected_theme"
  AUTOVAULT_NOTIFY="$notify_enabled"
  
  echo ""
  echo -e "${THEME[success]}${THEME[bold]}✓ Configuration complete!${THEME[reset]}"
  echo ""
  show_status
}

#--------------------------------------
# RESET
#--------------------------------------
reset_config() {
  if [[ -f "$THEME_CONFIG" ]]; then
    rm -f "$THEME_CONFIG"
    echo -e "${THEME[success]}✓ Configuration reset to defaults${THEME[reset]}"
  else
    echo "No configuration file to reset"
  fi
  
  set_theme "dark"
  AUTOVAULT_NOTIFY="true"
}

#--------------------------------------
# MAIN
#--------------------------------------
main() {
  # Load existing config
  load_theme_config
  set_theme "${AUTOVAULT_THEME:-dark}"
  
  local cmd="${1:-status}"
  shift || true
  
  case "$cmd" in
    -h|--help)
      usage
      ;;
    status)
      show_status
      ;;
    set)
      local theme="${1:-}"
      if [[ -z "$theme" ]]; then
        log_error "Theme name required"
        echo "Usage: $(basename "$0") set <dark|light|auto>"
        exit 1
      fi
      set_theme_cmd "$theme"
      ;;
    preview)
      preview_themes
      ;;
    config)
      interactive_config
      ;;
    reset)
      reset_config
      ;;
    *)
      log_error "Unknown command: $cmd"
      usage
      exit 1
      ;;
  esac
}

main "$@"
