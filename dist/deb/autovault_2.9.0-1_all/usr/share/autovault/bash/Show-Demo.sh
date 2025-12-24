#!/usr/bin/env bash
#===============================================================================
#
#  SCRIPT NAME:    Show-Demo.sh
#  DESCRIPTION:    Demonstrate AutoVault UI features
#                  Progress bars, spinners, themes, menus, notifications
#
#  USAGE:          ./Show-Demo.sh [component]
#
#  COMPONENTS:     all         Run all demos
#                  progress    Progress bar demo
#                  spinner     Spinner demo
#                  theme       Theme switching demo
#                  menu        Interactive menu demo
#                  notify      Notification demo
#                  box         Box/formatting demo
#
#  AUTHOR:         AutoVault Project
#  VERSION:        2.9.0
#
#===============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/ui.sh"

#--------------------------------------
# DEMOS
#--------------------------------------

demo_progress() {
  print_section "Progress Bar Demo"
  echo ""
  
  echo "Standard progress bar:"
  for i in {0..100..5}; do
    progress_bar "$i" 100 "Downloading..."
    sleep 0.05
  done
  
  echo ""
  echo "Progress with items:"
  local total=25
  for i in $(seq 1 $total); do
    printf "\r"
    progress_bar "$i" "$total" "Processing" 30
    printf " (%d/%d files)" "$i" "$total"
    sleep 0.08
  done
  echo ""
  
  echo ""
  echo -e "${THEME[success]}✓ Progress bar demo complete${THEME[reset]}"
}

demo_spinner() {
  print_section "Spinner Demo"
  echo ""
  
  echo "Background spinner (3 seconds):"
  spinner_start "Loading configuration..."
  sleep 3
  spinner_stop "${THEME[success]}✓ Configuration loaded${THEME[reset]}"
  
  echo ""
  echo "Spinner with task simulation:"
  spinner_start "Installing dependencies..."
  sleep 2
  spinner_stop "${THEME[success]}✓ Dependencies installed${THEME[reset]}"
  
  spinner_start "Building project..."
  sleep 2
  spinner_stop "${THEME[success]}✓ Build complete${THEME[reset]}"
  
  spinner_start "Running tests..."
  sleep 1.5
  spinner_stop "${THEME[success]}✓ All tests passed${THEME[reset]}"
  
  echo ""
  echo -e "${THEME[success]}✓ Spinner demo complete${THEME[reset]}"
}

demo_theme() {
  print_section "Theme Demo"
  echo ""
  
  echo "Current theme: $(get_theme)"
  echo ""
  
  echo "Dark theme colors:"
  set_theme "dark"
  echo -e "  ${THEME[primary]}Primary${THEME[reset]} | ${THEME[secondary]}Secondary${THEME[reset]} | ${THEME[success]}Success${THEME[reset]} | ${THEME[warning]}Warning${THEME[reset]} | ${THEME[error]}Error${THEME[reset]} | ${THEME[muted]}Muted${THEME[reset]}"
  echo -e "  Progress: ${THEME[success]}${THEME[bar_fill]}${THEME[bar_fill]}${THEME[bar_fill]}${THEME[bar_fill]}${THEME[bar_fill]}${THEME[reset]}${THEME[muted]}${THEME[bar_empty]}${THEME[bar_empty]}${THEME[bar_empty]}${THEME[bar_empty]}${THEME[bar_empty]}${THEME[reset]}"
  echo ""
  
  echo "Light theme colors:"
  set_theme "light"
  echo -e "  ${THEME[primary]}Primary${THEME[reset]} | ${THEME[secondary]}Secondary${THEME[reset]} | ${THEME[success]}Success${THEME[reset]} | ${THEME[warning]}Warning${THEME[reset]} | ${THEME[error]}Error${THEME[reset]} | ${THEME[muted]}Muted${THEME[reset]}"
  echo -e "  Progress: ${THEME[success]}${THEME[bar_fill]}${THEME[bar_fill]}${THEME[bar_fill]}${THEME[bar_fill]}${THEME[bar_fill]}${THEME[reset]}${THEME[muted]}${THEME[bar_empty]}${THEME[bar_empty]}${THEME[bar_empty]}${THEME[bar_empty]}${THEME[bar_empty]}${THEME[reset]}"
  echo ""
  
  # Reset to default
  set_theme "dark"
  
  echo -e "${THEME[success]}✓ Theme demo complete${THEME[reset]}"
}

demo_menu() {
  print_section "Interactive Menu Demo"
  echo ""
  
  echo "Simple selection menu:"
  local choice
  choice=$(select_menu "Choose a profile:" "minimal" "pentest" "audit" "bugbounty")
  echo -e "You selected: ${THEME[success]}$choice${THEME[reset]}"
  echo ""
  
  echo "Confirmation prompt:"
  if confirm "Do you want to continue?" "y"; then
    echo -e "${THEME[success]}✓ Continuing...${THEME[reset]}"
  else
    echo -e "${THEME[warning]}✗ Cancelled${THEME[reset]}"
  fi
  echo ""
  
  echo "Input prompt:"
  local name
  name=$(prompt_input "Enter project name:" "my-project")
  echo -e "Project name: ${THEME[success]}$name${THEME[reset]}"
  echo ""
  
  echo -e "${THEME[success]}✓ Menu demo complete${THEME[reset]}"
}

demo_notify() {
  print_section "Notification Demo"
  echo ""
  
  local notify_cmd
  notify_cmd=$(_get_notify_cmd)
  
  if [[ -n "$notify_cmd" ]]; then
    echo "Notification system: $notify_cmd"
    echo ""
    
    echo "Sending success notification..."
    notify_success "Demo completed successfully!"
    sleep 1
    
    echo "Sending warning notification..."
    notify_warning "This is a warning message"
    sleep 1
    
    echo "Sending error notification..."
    notify_error "This is an error message"
    
    echo ""
    echo -e "${THEME[success]}✓ Notifications sent${THEME[reset]}"
  else
    echo -e "${THEME[warning]}No notification system found${THEME[reset]}"
    echo "Install one of:"
    echo "  - notify-send (Linux)"
    echo "  - terminal-notifier (macOS via Homebrew)"
  fi
  echo ""
  
  echo -e "${THEME[success]}✓ Notification demo complete${THEME[reset]}"
}

demo_box() {
  print_section "Box & Formatting Demo"
  echo ""
  
  echo "Styled box:"
  print_box "AutoVault Status" \
    "Profile:   pentest" \
    "Customers: 15" \
    "Sections:  6" \
    "Templates: 12"
  
  echo ""
  echo "Key-value pairs:"
  print_kv "Version" "${AUTOVAULT_VERSION:-2.9.0}"
  print_kv "Theme" "$(get_theme)"
  print_kv "Config" "/path/to/config.json"
  
  echo ""
  echo "Table:"
  table_header "Customer" "Sections" "Status"
  table_row "ACME-001" "6/6" "✓ Complete"
  table_row "BETA-002" "4/6" "⚠ Partial"
  table_row "GAMMA-003" "0/6" "✗ Empty"
  
  echo ""
  echo -e "${THEME[success]}✓ Box demo complete${THEME[reset]}"
}

demo_all() {
  echo ""
  echo -e "${THEME[primary]}╔══════════════════════════════════════════════════════════════╗${THEME[reset]}"
  echo -e "${THEME[primary]}║${THEME[reset]}                                                              ${THEME[primary]}║${THEME[reset]}"
  echo -e "${THEME[primary]}║${THEME[reset]}    ${THEME[bold]}🎨 AutoVault UI Demo${THEME[reset]}                                    ${THEME[primary]}║${THEME[reset]}"
  echo -e "${THEME[primary]}║${THEME[reset]}                                                              ${THEME[primary]}║${THEME[reset]}"
  echo -e "${THEME[primary]}╚══════════════════════════════════════════════════════════════╝${THEME[reset]}"
  
  demo_progress
  echo ""
  demo_spinner
  echo ""
  demo_theme
  echo ""
  demo_box
  echo ""
  demo_notify
  
  echo ""
  echo -e "${THEME[primary]}════════════════════════════════════════════════════════════════${THEME[reset]}"
  echo -e "${THEME[success]}${THEME[bold]}✓ All demos complete!${THEME[reset]}"
  echo ""
}

#--------------------------------------
# USAGE
#--------------------------------------
usage() {
  cat << EOF
${THEME[bold]}USAGE${THEME[reset]}
    $(basename "$0") [COMPONENT]

${THEME[bold]}COMPONENTS${THEME[reset]}
    all         Run all demos (default)
    progress    Progress bar demo
    spinner     Spinner demo
    theme       Theme switching demo
    menu        Interactive menu demo
    notify      Notification demo
    box         Box/formatting demo

${THEME[bold]}ENVIRONMENT${THEME[reset]}
    AUTOVAULT_THEME    Set color theme (dark/light/auto)
    AUTOVAULT_NOTIFY   Enable notifications (true/false)
    NO_COLOR           Disable all colors

${THEME[bold]}EXAMPLES${THEME[reset]}
    $(basename "$0")                    # Run all demos
    $(basename "$0") progress           # Progress bar only
    AUTOVAULT_THEME=light $(basename "$0") theme  # Test light theme

EOF
}

#--------------------------------------
# MAIN
#--------------------------------------
main() {
  local component="${1:-all}"
  
  case "$component" in
    -h|--help)
      usage
      ;;
    all)
      demo_all
      ;;
    progress)
      demo_progress
      ;;
    spinner)
      demo_spinner
      ;;
    theme)
      demo_theme
      ;;
    menu)
      demo_menu
      ;;
    notify)
      demo_notify
      ;;
    box)
      demo_box
      ;;
    *)
      echo -e "${THEME[error]}Unknown component: $component${THEME[reset]}"
      usage
      exit 1
      ;;
  esac
}

main "$@"
