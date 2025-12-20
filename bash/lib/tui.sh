#!/usr/bin/env bash
#===============================================================================
#
#  AUTOVAULT LIBRARY - tui.sh
#
#===============================================================================
#
#  DESCRIPTION:    Terminal User Interface for AutoVault.
#                  Provides interactive menu-driven interface as alternative
#                  to CLI commands.
#
#  ACTIVATION:     ./cust-run-config.sh --tui
#                  ./cust-run-config.sh -i
#                  ./cust-run-config.sh tui
#
#  NAVIGATION:     ↑/↓ or j/k    - Move selection
#                  Enter/Space   - Select item
#                  q/Esc         - Back/Quit
#                  ?             - Help
#
#  REQUIREMENTS:   - Terminal with ANSI support
#                  - stty for raw input
#
#===============================================================================

# Prevent multiple sourcing
[[ -n "${_TUI_SH_LOADED:-}" ]] && return 0
_TUI_SH_LOADED=1

#--------------------------------------
# TUI CONFIGURATION
#--------------------------------------
TUI_ENABLED="${TUI_ENABLED:-false}"

# Colors for TUI (override if needed)
TUI_COLOR_TITLE="${TUI_COLOR_TITLE:-\033[1;36m}"      # Bold Cyan
TUI_COLOR_SELECTED="${TUI_COLOR_SELECTED:-\033[7m}"   # Reverse video
TUI_COLOR_HIGHLIGHT="${TUI_COLOR_HIGHLIGHT:-\033[1;33m}" # Bold Yellow
TUI_COLOR_DIM="${TUI_COLOR_DIM:-\033[2m}"             # Dim
TUI_COLOR_SUCCESS="${TUI_COLOR_SUCCESS:-\033[32m}"    # Green
TUI_COLOR_ERROR="${TUI_COLOR_ERROR:-\033[31m}"        # Red
TUI_COLOR_RESET="${TUI_COLOR_RESET:-\033[0m}"         # Reset

# Box drawing characters
BOX_TL="╭"
BOX_TR="╮"
BOX_BL="╰"
BOX_BR="╯"
BOX_H="─"
BOX_V="│"
BOX_SEP="├"
BOX_SEP_R="┤"

#--------------------------------------
# TERMINAL UTILITIES
#--------------------------------------

# Get terminal dimensions
tui_get_dimensions() {
    TUI_ROWS=$(tput lines)
    TUI_COLS=$(tput cols)
}

# Hide cursor
tui_hide_cursor() {
    echo -ne "\033[?25l"
}

# Show cursor
tui_show_cursor() {
    echo -ne "\033[?25h"
}

# Clear screen
tui_clear() {
    echo -ne "\033[2J\033[H"
}

# Move cursor
tui_move_cursor() {
    local row=$1 col=$2
    echo -ne "\033[${row};${col}H"
}

# Save/restore cursor position
tui_save_cursor() { echo -ne "\033[s"; }
tui_restore_cursor() { echo -ne "\033[u"; }

# Read single key with proper escape sequence handling
tui_read_key() {
    local key
    local seq1 seq2 seq3
    
    # Read first character (blocking)
    IFS= read -rsn1 key 2>/dev/null || return 1
    
    # Handle escape sequences (arrows, function keys, etc.)
    if [[ "$key" == $'\x1b' ]] || [[ "$key" == $'\e' ]]; then
        # Check if more characters are available (escape sequence)
        if IFS= read -rsn1 -t 0.01 seq1 2>/dev/null; then
            if [[ "$seq1" == "[" ]]; then
                # CSI sequence - read the final character
                if IFS= read -rsn1 -t 0.01 seq2 2>/dev/null; then
                    case "$seq2" in
                        'A') echo "UP" ; return 0 ;;
                        'B') echo "DOWN" ; return 0 ;;
                        'C') echo "RIGHT" ; return 0 ;;
                        'D') echo "LEFT" ; return 0 ;;
                        'H') echo "HOME" ; return 0 ;;
                        'F') echo "END" ; return 0 ;;
                        '1'|'2'|'3'|'4'|'5'|'6')
                            # Extended sequence like [1~ (Home), [4~ (End)
                            IFS= read -rsn1 -t 0.01 seq3 2>/dev/null
                            case "${seq2}${seq3}" in
                                '1~'|'7~') echo "HOME" ; return 0 ;;
                                '4~'|'8~') echo "END" ; return 0 ;;
                                '3~') echo "DELETE" ; return 0 ;;
                                '5~') echo "PAGEUP" ; return 0 ;;
                                '6~') echo "PAGEDOWN" ; return 0 ;;
                            esac
                            ;;
                    esac
                fi
            elif [[ "$seq1" == "O" ]]; then
                # SS3 sequence (some terminals use this for arrows)
                if IFS= read -rsn1 -t 0.01 seq2 2>/dev/null; then
                    case "$seq2" in
                        'A') echo "UP" ; return 0 ;;
                        'B') echo "DOWN" ; return 0 ;;
                        'C') echo "RIGHT" ; return 0 ;;
                        'D') echo "LEFT" ; return 0 ;;
                        'H') echo "HOME" ; return 0 ;;
                        'F') echo "END" ; return 0 ;;
                    esac
                fi
            fi
        fi
        # Just ESC key pressed alone
        echo "ESC"
        return 0
    fi
    
    # Regular key handling
    case "$key" in
        '') echo "ENTER" ;;
        ' ') echo "SPACE" ;;
        'q'|'Q') echo "QUIT" ;;
        'j'|'J') echo "DOWN" ;;
        'k'|'K') echo "UP" ;;
        'h'|'H') echo "LEFT" ;;
        'l'|'L') echo "RIGHT" ;;
        '?') echo "HELP" ;;
        $'\x7f'|$'\b') echo "BACKSPACE" ;;
        [0-9]) echo "$key" ;;
        *) echo "$key" ;;
    esac
    return 0
}

#--------------------------------------
# DRAWING UTILITIES
#--------------------------------------

# Draw horizontal line
tui_draw_hline() {
    local width=$1
    local char="${2:-$BOX_H}"
    printf '%*s' "$width" '' | tr ' ' "$char"
}

# Draw box
tui_draw_box() {
    local row=$1 col=$2 width=$3 height=$4 title="${5:-}"
    
    # Top border
    tui_move_cursor "$row" "$col"
    echo -ne "$BOX_TL"
    if [[ -n "$title" ]]; then
        local title_len=${#title}
        local left_pad=$(( (width - title_len - 4) / 2 ))
        local right_pad=$(( width - title_len - 4 - left_pad ))
        tui_draw_hline "$left_pad"
        echo -ne " ${TUI_COLOR_TITLE}${title}${TUI_COLOR_RESET} "
        tui_draw_hline "$right_pad"
    else
        tui_draw_hline $((width - 2))
    fi
    echo -ne "$BOX_TR"
    
    # Sides
    for ((i = 1; i < height - 1; i++)); do
        tui_move_cursor $((row + i)) "$col"
        echo -ne "$BOX_V"
        printf '%*s' $((width - 2)) ''
        echo -ne "$BOX_V"
    done
    
    # Bottom border
    tui_move_cursor $((row + height - 1)) "$col"
    echo -ne "$BOX_BL"
    tui_draw_hline $((width - 2))
    echo -ne "$BOX_BR"
}

# Draw centered text
tui_draw_centered() {
    local row=$1 text="$2" color="${3:-}"
    local col=$(( (TUI_COLS - ${#text}) / 2 ))
    tui_move_cursor "$row" "$col"
    [[ -n "$color" ]] && echo -ne "$color"
    echo -n "$text"
    [[ -n "$color" ]] && echo -ne "$TUI_COLOR_RESET"
}

#--------------------------------------
# MENU SYSTEM
#--------------------------------------

# Global menu state
declare -a TUI_MENU_ITEMS=()
declare -a TUI_MENU_ACTIONS=()
TUI_MENU_SELECTED=0
TUI_MENU_TITLE=""

# Set menu items
# Usage: tui_menu_set "Title" "Item1:action1" "Item2:action2" ...
tui_menu_set() {
    TUI_MENU_TITLE="$1"
    shift
    
    TUI_MENU_ITEMS=()
    TUI_MENU_ACTIONS=()
    TUI_MENU_SELECTED=0
    
    for item in "$@"; do
        local label="${item%%:*}"
        local action="${item#*:}"
        TUI_MENU_ITEMS+=("$label")
        TUI_MENU_ACTIONS+=("$action")
    done
}

# Draw menu
tui_menu_draw() {
    local start_row=$1 start_col=$2 width=$3
    local count=${#TUI_MENU_ITEMS[@]}
    
    for ((i = 0; i < count; i++)); do
        tui_move_cursor $((start_row + i)) "$start_col"
        
        # Clear line area
        printf '%*s' "$width" ''
        tui_move_cursor $((start_row + i)) "$start_col"
        
        if [[ $i -eq $TUI_MENU_SELECTED ]]; then
            echo -ne "${TUI_COLOR_SELECTED}"
            printf " %-$((width - 2))s " "${TUI_MENU_ITEMS[$i]}"
            echo -ne "${TUI_COLOR_RESET}"
        else
            printf "  %-$((width - 2))s" "${TUI_MENU_ITEMS[$i]}"
        fi
    done
}

# Handle menu input
# Returns: selected action or empty on quit
tui_menu_handle() {
    local count=${#TUI_MENU_ITEMS[@]}
    
    while true; do
        local key
        key=$(tui_read_key)
        
        case "$key" in
            UP)
                ((TUI_MENU_SELECTED--))
                [[ $TUI_MENU_SELECTED -lt 0 ]] && TUI_MENU_SELECTED=$((count - 1))
                return 1  # Redraw needed
                ;;
            DOWN)
                ((TUI_MENU_SELECTED++))
                [[ $TUI_MENU_SELECTED -ge $count ]] && TUI_MENU_SELECTED=0
                return 1  # Redraw needed
                ;;
            ENTER|SPACE)
                echo "${TUI_MENU_ACTIONS[$TUI_MENU_SELECTED]}"
                return 0
                ;;
            QUIT|ESC)
                echo "quit"
                return 0
                ;;
            [0-9])
                local idx=$((key - 1))
                if [[ $idx -ge 0 ]] && [[ $idx -lt $count ]]; then
                    TUI_MENU_SELECTED=$idx
                    echo "${TUI_MENU_ACTIONS[$idx]}"
                    return 0
                fi
                ;;
        esac
    done
}

#--------------------------------------
# INPUT DIALOGS
#--------------------------------------

# Simple input prompt
# Usage: result=$(tui_input "Prompt" "default")
tui_input() {
    local prompt="$1"
    local default="${2:-}"
    local result
    
    tui_show_cursor
    echo -ne "\n  ${TUI_COLOR_HIGHLIGHT}${prompt}${TUI_COLOR_RESET}"
    [[ -n "$default" ]] && echo -ne " [${default}]"
    echo -ne ": "
    
    read -r result
    tui_hide_cursor
    
    echo "${result:-$default}"
}

# Confirmation dialog
# Usage: if tui_confirm "Are you sure?"; then ...
tui_confirm() {
    local prompt="$1"
    local default="${2:-n}"
    
    tui_show_cursor
    echo -ne "\n  ${TUI_COLOR_HIGHLIGHT}${prompt}${TUI_COLOR_RESET}"
    if [[ "$default" == "y" ]]; then
        echo -ne " [Y/n]: "
    else
        echo -ne " [y/N]: "
    fi
    
    local response
    read -rn1 response
    echo
    tui_hide_cursor
    
    response="${response:-$default}"
    [[ "$response" =~ ^[Yy]$ ]]
}

# Selection list
# Usage: result=$(tui_select "Choose" "opt1" "opt2" "opt3")
tui_select() {
    local title="$1"
    shift
    local options=("$@")
    local selected=0
    local count=${#options[@]}
    
    tui_hide_cursor
    
    # Save cursor position
    echo -ne "\n"
    local start_row
    start_row=$(tput csr | head -1)
    
    while true; do
        # Draw options
        echo -ne "\r\033[K  ${TUI_COLOR_HIGHLIGHT}${title}${TUI_COLOR_RESET}\n"
        
        for ((i = 0; i < count; i++)); do
            echo -ne "\033[K"
            if [[ $i -eq $selected ]]; then
                echo -e "  ${TUI_COLOR_SELECTED} ${options[$i]} ${TUI_COLOR_RESET}"
            else
                echo -e "    ${options[$i]}"
            fi
        done
        
        # Move cursor back up
        echo -ne "\033[$((count + 1))A"
        
        local key
        key=$(tui_read_key)
        
        case "$key" in
            UP)
                ((selected--))
                [[ $selected -lt 0 ]] && selected=$((count - 1))
                ;;
            DOWN)
                ((selected++))
                [[ $selected -ge $count ]] && selected=0
                ;;
            ENTER|SPACE)
                # Clear and return
                for ((i = 0; i <= count; i++)); do
                    echo -ne "\033[K\n"
                done
                echo -ne "\033[$((count + 1))A"
                tui_show_cursor
                echo "${options[$selected]}"
                return 0
                ;;
            QUIT|ESC)
                for ((i = 0; i <= count; i++)); do
                    echo -ne "\033[K\n"
                done
                echo -ne "\033[$((count + 1))A"
                tui_show_cursor
                return 1
                ;;
        esac
    done
}

#--------------------------------------
# STATUS & MESSAGES
#--------------------------------------

# Show status message
tui_status() {
    local message="$1"
    local type="${2:-info}"  # info, success, error, warn
    
    local color
    case "$type" in
        success) color="$TUI_COLOR_SUCCESS" ;;
        error)   color="$TUI_COLOR_ERROR" ;;
        warn)    color="$TUI_COLOR_HIGHLIGHT" ;;
        *)       color="$TUI_COLOR_RESET" ;;
    esac
    
    tui_move_cursor $((TUI_ROWS - 2)) 2
    echo -ne "\033[K"  # Clear line
    echo -ne "${color}${message}${TUI_COLOR_RESET}"
}

# Show help overlay
tui_show_help() {
    tui_get_dimensions
    local width=50
    local height=12
    local row=$(( (TUI_ROWS - height) / 2 ))
    local col=$(( (TUI_COLS - width) / 2 ))
    
    tui_draw_box "$row" "$col" "$width" "$height" "Keyboard Shortcuts"
    
    local help_items=(
        "  ↑/k     Move up"
        "  ↓/j     Move down"
        "  Enter   Select item"
        "  q/Esc   Back / Quit"
        "  1-9     Quick select"
        "  ?       Show this help"
    )
    
    for ((i = 0; i < ${#help_items[@]}; i++)); do
        tui_move_cursor $((row + 2 + i)) $((col + 2))
        echo -ne "${help_items[$i]}"
    done
    
    tui_move_cursor $((row + height - 2)) $((col + 2))
    echo -ne "${TUI_COLOR_DIM}Press any key to close${TUI_COLOR_RESET}"
    
    tui_read_key >/dev/null
}

#--------------------------------------
# MAIN TUI SCREENS
#--------------------------------------

# Main menu
tui_main_menu() {
    tui_menu_set "AutoVault" \
        "📊 Status:status" \
        "📁 Structure:structure" \
        "📝 Templates:templates" \
        "👤 Customers:customers" \
        "📂 Sections:sections" \
        "💾 Backups:backups" \
        "🌐 Remote Sync:remote" \
        "🪝 Hooks:hooks" \
        "⚙️  Configuration:config" \
        "❓ Help:help" \
        "🚪 Quit:quit"
}

# Customers submenu
tui_customers_menu() {
    tui_menu_set "Customers" \
        "📋 List customers:customer_list" \
        "➕ Add customer:customer_add" \
        "➖ Remove customer:customer_remove" \
        "📤 Export customer:customer_export" \
        "📥 Import customer:customer_import" \
        "📋 Clone customer:customer_clone" \
        "← Back:back"
}

# Templates submenu
tui_templates_menu() {
    tui_menu_set "Templates" \
        "📋 List templates:templates_list" \
        "🔄 Sync templates:templates_sync" \
        "✅ Apply templates:templates_apply" \
        "👁️  Preview template:templates_preview" \
        "📤 Export templates:templates_export" \
        "← Back:back"
}

# Backups submenu
tui_backups_menu() {
    tui_menu_set "Backups" \
        "📋 List backups:backup_list" \
        "💾 Create backup:backup_create" \
        "♻️  Restore backup:backup_restore" \
        "🗑️  Cleanup old:backup_cleanup" \
        "← Back:back"
}

# Remote submenu
tui_remote_menu() {
    tui_menu_set "Remote Sync" \
        "📋 List remotes:remote_list" \
        "➕ Add remote:remote_add" \
        "🔍 Test connection:remote_test" \
        "⬆️  Push to remote:remote_push" \
        "⬇️  Pull from remote:remote_pull" \
        "📊 Sync status:remote_status" \
        "← Back:back"
}

#--------------------------------------
# TUI MAIN LOOP
#--------------------------------------

tui_run() {
    # Check terminal capability
    if [[ ! -t 0 ]] || [[ ! -t 1 ]]; then
        log_error "TUI requires an interactive terminal"
        return 1
    fi
    
    # Save original terminal settings
    TUI_ORIGINAL_STTY=$(stty -g)
    
    # Setup terminal for raw input (disable line buffering and echo)
    stty -echo -icanon min 1 time 0
    
    # Setup
    tui_get_dimensions
    tui_hide_cursor
    tui_clear
    
    # Trap to restore terminal on exit
    trap 'tui_cleanup' EXIT INT TERM
    
    local current_menu="main"
    local action=""
    
    while true; do
        tui_clear
        tui_get_dimensions
        
        # Draw header
        tui_draw_centered 2 "╔═══════════════════════════════════════╗" "$TUI_COLOR_TITLE"
        tui_draw_centered 3 "║          A U T O V A U L T            ║" "$TUI_COLOR_TITLE"
        tui_draw_centered 4 "╚═══════════════════════════════════════╝" "$TUI_COLOR_TITLE"
        
        # Load appropriate menu
        case "$current_menu" in
            main)       tui_main_menu ;;
            customers)  tui_customers_menu ;;
            templates)  tui_templates_menu ;;
            backups)    tui_backups_menu ;;
            remote)     tui_remote_menu ;;
        esac
        
        # Draw menu title
        tui_move_cursor 6 4
        echo -ne "${TUI_COLOR_HIGHLIGHT}${TUI_MENU_TITLE}${TUI_COLOR_RESET}"
        
        # Draw menu items
        tui_menu_draw 8 4 40
        
        # Draw footer
        tui_move_cursor $((TUI_ROWS - 1)) 2
        echo -ne "${TUI_COLOR_DIM}↑↓:Navigate  Enter:Select  q:Quit  ?:Help${TUI_COLOR_RESET}"
        
        # Handle input
        action=$(tui_menu_handle)
        local result=$?
        
        if [[ $result -eq 1 ]]; then
            # Just redraw (navigation)
            continue
        fi
        
        # Process action
        case "$action" in
            # Navigation
            quit)
                break
                ;;
            back)
                current_menu="main"
                ;;
            customers|templates|backups|remote)
                current_menu="$action"
                ;;
            help)
                tui_show_help
                ;;
            
            # Status & Config
            status)
                tui_clear
                tui_show_cursor
                bash "$BASH_DIR/Show-Status.sh"
                echo -e "\n${TUI_COLOR_DIM}Press any key to continue...${TUI_COLOR_RESET}"
                tui_hide_cursor
                tui_read_key >/dev/null
                ;;
            config)
                tui_clear
                tui_show_cursor
                interactive_config
                tui_hide_cursor
                ;;
            structure)
                tui_clear
                tui_show_cursor
                bash "$BASH_DIR/New-CustRunStructure.sh"
                echo -e "\n${TUI_COLOR_DIM}Press any key to continue...${TUI_COLOR_RESET}"
                tui_hide_cursor
                tui_read_key >/dev/null
                ;;
            hooks)
                tui_clear
                tui_show_cursor
                list_hooks
                echo -e "\n${TUI_COLOR_DIM}Press any key to continue...${TUI_COLOR_RESET}"
                tui_hide_cursor
                tui_read_key >/dev/null
                ;;
            
            # Customer actions
            customer_list)
                tui_clear
                tui_show_cursor
                bash "$BASH_DIR/Manage-Customers.sh" list -v
                echo -e "\n${TUI_COLOR_DIM}Press any key to continue...${TUI_COLOR_RESET}"
                tui_hide_cursor
                tui_read_key >/dev/null
                ;;
            customer_add)
                tui_clear
                tui_show_cursor
                local cust_id
                cust_id=$(tui_input "Enter customer ID")
                if [[ -n "$cust_id" ]]; then
                    bash "$BASH_DIR/Manage-Customers.sh" add "$cust_id"
                fi
                echo -e "\n${TUI_COLOR_DIM}Press any key to continue...${TUI_COLOR_RESET}"
                tui_hide_cursor
                tui_read_key >/dev/null
                ;;
            customer_remove)
                tui_clear
                tui_show_cursor
                local cust_id
                cust_id=$(tui_input "Enter customer ID to remove")
                if [[ -n "$cust_id" ]]; then
                    bash "$BASH_DIR/Manage-Customers.sh" remove "$cust_id"
                fi
                echo -e "\n${TUI_COLOR_DIM}Press any key to continue...${TUI_COLOR_RESET}"
                tui_hide_cursor
                tui_read_key >/dev/null
                ;;
            customer_export)
                tui_clear
                tui_show_cursor
                local cust_id
                cust_id=$(tui_input "Enter customer ID to export")
                if [[ -n "$cust_id" ]]; then
                    bash "$BASH_DIR/Manage-Customers.sh" export "$cust_id"
                fi
                echo -e "\n${TUI_COLOR_DIM}Press any key to continue...${TUI_COLOR_RESET}"
                tui_hide_cursor
                tui_read_key >/dev/null
                ;;
            customer_import)
                tui_clear
                tui_show_cursor
                local file
                file=$(tui_input "Enter export file path")
                if [[ -n "$file" ]]; then
                    bash "$BASH_DIR/Manage-Customers.sh" import "$file"
                fi
                echo -e "\n${TUI_COLOR_DIM}Press any key to continue...${TUI_COLOR_RESET}"
                tui_hide_cursor
                tui_read_key >/dev/null
                ;;
            customer_clone)
                tui_clear
                tui_show_cursor
                local src_id dest_id
                src_id=$(tui_input "Enter source customer ID")
                dest_id=$(tui_input "Enter destination customer ID")
                if [[ -n "$src_id" ]] && [[ -n "$dest_id" ]]; then
                    bash "$BASH_DIR/Manage-Customers.sh" clone "$src_id" "$dest_id"
                fi
                echo -e "\n${TUI_COLOR_DIM}Press any key to continue...${TUI_COLOR_RESET}"
                tui_hide_cursor
                tui_read_key >/dev/null
                ;;
            
            # Template actions
            templates_list)
                tui_clear
                tui_show_cursor
                bash "$BASH_DIR/Manage-Templates.sh" list
                echo -e "\n${TUI_COLOR_DIM}Press any key to continue...${TUI_COLOR_RESET}"
                tui_hide_cursor
                tui_read_key >/dev/null
                ;;
            templates_sync)
                tui_clear
                tui_show_cursor
                bash "$BASH_DIR/Manage-Templates.sh" sync
                echo -e "\n${TUI_COLOR_DIM}Press any key to continue...${TUI_COLOR_RESET}"
                tui_hide_cursor
                tui_read_key >/dev/null
                ;;
            templates_apply)
                tui_clear
                tui_show_cursor
                bash "$BASH_DIR/Manage-Templates.sh" apply
                echo -e "\n${TUI_COLOR_DIM}Press any key to continue...${TUI_COLOR_RESET}"
                tui_hide_cursor
                tui_read_key >/dev/null
                ;;
            templates_preview)
                tui_clear
                tui_show_cursor
                local tmpl
                tmpl=$(tui_input "Template name" "root")
                bash "$BASH_DIR/Manage-Templates.sh" preview "$tmpl"
                echo -e "\n${TUI_COLOR_DIM}Press any key to continue...${TUI_COLOR_RESET}"
                tui_hide_cursor
                tui_read_key >/dev/null
                ;;
            templates_export)
                tui_clear
                tui_show_cursor
                bash "$BASH_DIR/Manage-Templates.sh" export
                echo -e "\n${TUI_COLOR_DIM}Press any key to continue...${TUI_COLOR_RESET}"
                tui_hide_cursor
                tui_read_key >/dev/null
                ;;
            
            # Backup actions
            backup_list)
                tui_clear
                tui_show_cursor
                bash "$BASH_DIR/Manage-Backups.sh" list
                echo -e "\n${TUI_COLOR_DIM}Press any key to continue...${TUI_COLOR_RESET}"
                tui_hide_cursor
                tui_read_key >/dev/null
                ;;
            backup_create)
                tui_clear
                tui_show_cursor
                local note
                note=$(tui_input "Backup note (optional)")
                bash "$BASH_DIR/Manage-Backups.sh" create "$note"
                echo -e "\n${TUI_COLOR_DIM}Press any key to continue...${TUI_COLOR_RESET}"
                tui_hide_cursor
                tui_read_key >/dev/null
                ;;
            backup_restore)
                tui_clear
                tui_show_cursor
                bash "$BASH_DIR/Manage-Backups.sh" list
                echo ""
                local backup
                backup=$(tui_input "Enter backup filename to restore")
                if [[ -n "$backup" ]]; then
                    bash "$BASH_DIR/Manage-Backups.sh" restore "$backup"
                fi
                echo -e "\n${TUI_COLOR_DIM}Press any key to continue...${TUI_COLOR_RESET}"
                tui_hide_cursor
                tui_read_key >/dev/null
                ;;
            backup_cleanup)
                tui_clear
                tui_show_cursor
                local keep
                keep=$(tui_input "Number of backups to keep" "5")
                bash "$BASH_DIR/Manage-Backups.sh" cleanup "$keep"
                echo -e "\n${TUI_COLOR_DIM}Press any key to continue...${TUI_COLOR_RESET}"
                tui_hide_cursor
                tui_read_key >/dev/null
                ;;
            
            # Remote actions
            remote_list)
                tui_clear
                tui_show_cursor
                list_remotes
                echo -e "\n${TUI_COLOR_DIM}Press any key to continue...${TUI_COLOR_RESET}"
                tui_hide_cursor
                tui_read_key >/dev/null
                ;;
            remote_add)
                tui_clear
                tui_show_cursor
                local name host path port
                name=$(tui_input "Remote name")
                host=$(tui_input "Host (user@server)")
                path=$(tui_input "Remote path")
                port=$(tui_input "SSH port" "22")
                if [[ -n "$name" ]] && [[ -n "$host" ]] && [[ -n "$path" ]]; then
                    add_remote "$name" "$host" "$path" "$port"
                fi
                echo -e "\n${TUI_COLOR_DIM}Press any key to continue...${TUI_COLOR_RESET}"
                tui_hide_cursor
                tui_read_key >/dev/null
                ;;
            remote_test)
                tui_clear
                tui_show_cursor
                list_remotes
                echo ""
                local name
                name=$(tui_input "Remote name to test")
                if [[ -n "$name" ]]; then
                    test_remote "$name"
                fi
                echo -e "\n${TUI_COLOR_DIM}Press any key to continue...${TUI_COLOR_RESET}"
                tui_hide_cursor
                tui_read_key >/dev/null
                ;;
            remote_push)
                tui_clear
                tui_show_cursor
                list_remotes
                echo ""
                local name
                name=$(tui_input "Remote name to push to")
                if [[ -n "$name" ]]; then
                    if tui_confirm "Push to '$name'?"; then
                        remote_push "$name"
                    fi
                fi
                echo -e "\n${TUI_COLOR_DIM}Press any key to continue...${TUI_COLOR_RESET}"
                tui_hide_cursor
                tui_read_key >/dev/null
                ;;
            remote_pull)
                tui_clear
                tui_show_cursor
                list_remotes
                echo ""
                local name
                name=$(tui_input "Remote name to pull from")
                if [[ -n "$name" ]]; then
                    if tui_confirm "Pull from '$name'? This will overwrite local changes."; then
                        remote_pull "$name"
                    fi
                fi
                echo -e "\n${TUI_COLOR_DIM}Press any key to continue...${TUI_COLOR_RESET}"
                tui_hide_cursor
                tui_read_key >/dev/null
                ;;
            remote_status)
                tui_clear
                tui_show_cursor
                list_remotes
                echo ""
                local name
                name=$(tui_input "Remote name")
                if [[ -n "$name" ]]; then
                    remote_status "$name"
                fi
                echo -e "\n${TUI_COLOR_DIM}Press any key to continue...${TUI_COLOR_RESET}"
                tui_hide_cursor
                tui_read_key >/dev/null
                ;;
        esac
    done
    
    tui_cleanup
}

# Cleanup function
tui_cleanup() {
    # Restore original terminal settings
    if [[ -n "${TUI_ORIGINAL_STTY:-}" ]]; then
        stty "$TUI_ORIGINAL_STTY" 2>/dev/null || true
    fi
    tui_show_cursor
    tui_clear
    echo "Goodbye! 👋"
}
