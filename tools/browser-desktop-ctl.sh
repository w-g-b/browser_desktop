#!/bin/bash
# browser-desktop-ctl.sh - Management tool for browser-desktop system
#
# Usage: browser-desktop-ctl.sh <command> [arguments]
#
# Commands:
#   add-url <url>                 Add URL to whitelist
#   remove-url <url>              Remove URL from whitelist
#   list-urls                     List all whitelisted URLs
#   add-user <name> [--password]  Create kiosk user
#   delete-user <name>            Delete kiosk user
#   list-users                    List all kiosk users
#   reset-user <name>             Reset user's kiosk profile
#   apply                         Regenerate Chrome policy and portal page
#   help                          Show this help message

set -e

# Resolve script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source common library
# shellcheck source=../lib/common.sh
source "${PROJECT_DIR}/lib/common.sh"

# Configuration paths
readonly WHITELIST_CONF="/etc/browser-desktop/whitelist.conf"
readonly CHROME_POLICY_DIR="/etc/opt/chrome/policies/managed"
readonly CHROME_POLICY_FILE="${CHROME_POLICY_DIR}/browser-desktop.json"
readonly PORTAL_DIR="/opt/browser-desktop/portal"
readonly PORTAL_INDEX="${PORTAL_DIR}/index.html"
readonly USER_GROUP="browser-users"
readonly POLICY_TEMPLATE="${PROJECT_DIR}/config/chrome/managed-policy.json"

###############################################################################
# Help / Usage
###############################################################################

usage() {
    cat <<'USAGE'
browser-desktop-ctl - Management tool for browser-desktop system

Usage: browser-desktop-ctl <command> [arguments]

URL Management:
  add-url <url>                   Add URL to whitelist
  remove-url <url>                Remove URL from whitelist
  list-urls                       List all whitelisted URLs

User Management:
  add-user <username>             Create kiosk user (generates password)
  add-user <username> --password <pass>
                                  Create kiosk user with specified password
  delete-user <username>          Delete kiosk user
  list-users                      List all kiosk users
  reset-user <username>           Reset user's kiosk profile

Other:
  apply                           Regenerate Chrome policy and portal page
  help                            Show this help message

Examples:
  browser-desktop-ctl add-url "https://example.com"
  browser-desktop-ctl add-user kiosk1 --password "secret123"
  browser-desktop-ctl apply
USAGE
}

###############################################################################
# URL Management Commands
###############################################################################

cmd_add_url() {
    local url="${1:-}"

    if [[ -z "$url" ]]; then
        die "Usage: browser-desktop-ctl add-url <url>"
    fi

    # Ensure whitelist file exists
    if [[ ! -f "$WHITELIST_CONF" ]]; then
        ensure_dir "$(dirname "$WHITELIST_CONF")"
        touch "$WHITELIST_CONF"
        log_info "Created whitelist file: $WHITELIST_CONF"
    fi

    # Check for duplicate
    if grep -qxF "$url" "$WHITELIST_CONF" 2>/dev/null; then
        log_warn "URL already in whitelist: $url"
        return 0
    fi

    # Append URL
    echo "$url" >> "$WHITELIST_CONF"
    log_success "Added URL to whitelist: $url"
}

cmd_remove_url() {
    local url="${1:-}"

    if [[ -z "$url" ]]; then
        die "Usage: browser-desktop-ctl remove-url <url>"
    fi

    if [[ ! -f "$WHITELIST_CONF" ]]; then
        die "Whitelist file does not exist: $WHITELIST_CONF"
    fi

    if ! grep -qxF "$url" "$WHITELIST_CONF" 2>/dev/null; then
        die "URL not found in whitelist: $url"
    fi

    # Remove the exact matching line
    local tmp
    tmp=$(mktemp)
    grep -vxF "$url" "$WHITELIST_CONF" > "$tmp" || true
    mv "$tmp" "$WHITELIST_CONF"
    log_success "Removed URL from whitelist: $url"
}

cmd_list_urls() {
    if [[ ! -f "$WHITELIST_CONF" ]]; then
        log_warn "Whitelist file does not exist: $WHITELIST_CONF"
        return 0
    fi

    log_info "Whitelisted URLs:"
    echo ""

    local count=0
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        echo "  $line"
        count=$((count + 1))
    done < "$WHITELIST_CONF"

    echo ""
    log_info "Total: $count URL(s)"
}

###############################################################################
# User Management Commands
###############################################################################

cmd_add_user() {
    local username="${1:-}"
    local password=""

    if [[ -z "$username" ]]; then
        die "Usage: browser-desktop-ctl add-user <username> [--password <pass>]"
    fi

    shift

    # Parse optional --password flag
    if [[ "${1:-}" == "--password" ]]; then
        password="${2:-}"
        if [[ -z "$password" ]]; then
            die "--password requires a value"
        fi
    fi

    # Generate password if not provided
    if [[ -z "$password" ]]; then
        password="$(generate_password 16)"
        log_info "Generated password for user '$username': $password"
    fi

    # Ensure browser-users group exists
    if ! getent group "$USER_GROUP" >/dev/null 2>&1; then
        groupadd "$USER_GROUP"
        log_info "Created group: $USER_GROUP"
    fi

    # Check if user already exists
    if id "$username" >/dev/null 2>&1; then
        die "User already exists: $username"
    fi

    # Create user with home directory and add to browser-users group
    useradd -m -G "$USER_GROUP" -s /bin/bash "$username"
    log_info "Created user: $username (group: $USER_GROUP)"

    # Set password
    echo "${username}:${password}" | chpasswd
    log_success "User '$username' created and added to group '$USER_GROUP'"
}

cmd_delete_user() {
    local username="${1:-}"

    if [[ -z "$username" ]]; then
        die "Usage: browser-desktop-ctl delete-user <username>"
    fi

    # Check user exists
    if ! id "$username" >/dev/null 2>&1; then
        die "User does not exist: $username"
    fi

    # Check user is in browser-users group (safety check)
    if ! id -nG "$username" | tr ' ' '\n' | grep -qx "$USER_GROUP"; then
        die "User '$username' is not a member of group '$USER_GROUP' (refusing to delete non-kiosk user)"
    fi

    # Delete user and home directory
    userdel -r "$username" 2>/dev/null || userdel "$username"
    log_success "Deleted user: $username"
}

cmd_list_users() {
    if ! getent group "$USER_GROUP" >/dev/null 2>&1; then
        log_warn "Group '$USER_GROUP' does not exist. No kiosk users configured."
        return 0
    fi

    log_info "Users in group '$USER_GROUP':"
    echo ""

    local members
    members="$(getent group "$USER_GROUP" | cut -d: -f4)"

    if [[ -z "$members" ]]; then
        echo "  (no members)"
    else
        local IFS=','
        for user in $members; do
            echo "  $user"
        done
    fi

    echo ""
    local count
    count="$(echo "$members" | tr ',' '\n' | grep -c . || true)"
    log_info "Total: $count user(s)"
}

cmd_reset_user() {
    local username="${1:-}"

    if [[ -z "$username" ]]; then
        die "Usage: browser-desktop-ctl reset-user <username>"
    fi

    # Check user exists
    if ! id "$username" >/dev/null 2>&1; then
        die "User does not exist: $username"
    fi

    local kiosk_dir
    kiosk_dir="$(eval echo "~${username}")/.chrome-kiosk"

    if [[ ! -d "$kiosk_dir" ]]; then
        log_warn "Kiosk directory does not exist: $kiosk_dir"
        return 0
    fi

    rm -rf "$kiosk_dir"
    log_success "Reset user '$username': removed $kiosk_dir"
}

###############################################################################
# Apply Command (stub - implemented in Task 16)
###############################################################################

cmd_apply() {
    log_info "Applying configuration..."
    # TODO: Task 16 - implement generate_chrome_policy and generate_portal_page
    log_warn "apply command is not yet fully implemented (Task 16)"
}

###############################################################################
# Main Dispatch
###############################################################################

main() {
    local command="${1:-help}"

    # All commands except 'help' require root
    if [[ "$command" != "help" ]]; then
        check_root
    fi

    case "$command" in
        add-url)
            shift
            cmd_add_url "$@"
            ;;
        remove-url)
            shift
            cmd_remove_url "$@"
            ;;
        list-urls)
            cmd_list_urls
            ;;
        add-user)
            shift
            cmd_add_user "$@"
            ;;
        delete-user)
            shift
            cmd_delete_user "$@"
            ;;
        list-users)
            cmd_list_users
            ;;
        reset-user)
            shift
            cmd_reset_user "$@"
            ;;
        apply)
            cmd_apply
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            usage
            exit 1
            ;;
    esac
}

main "$@"
