#!/bin/bash
# Uninstall script for browser-desktop
# Removes browser-desktop files, restores xrdp backups, and stops services

set -e

# Resolve script directory and source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# Paths
readonly BROWSER_DESKTOP_DIR="/opt/browser-desktop"
readonly BROWSER_DESKTOP_ETC="/etc/browser-desktop"
readonly CHROME_POLICY_FILE="/etc/opt/chrome/policies/managed/browser-desktop.json"
readonly CTL_SYMLINK="/usr/local/bin/browser-desktop-ctl"
readonly XRDP_CONF_DIR="/etc/xrdp"

###############################################################################
# Banner
###############################################################################

show_banner() {
    cat <<'BANNER'
 ____                                    _   _       _           _        _ _
| __ ) _ __ _____      _____  ___ _ __  | | | |_ __ (_)_ __  ___| |_ __ _| | |
|  _ \| '__/ _ \ \ /\ / / __|/ _ \ '__| | | | | '_ \| | '_ \/ __| __/ _` | | |
| |_) | | | (_) \ V  V /\__ \  __/ |    | |_| | | | | | | | \__ \ || (_| | | |
|____/|_|  \___/ \_/\_/ |___/\___|_|     \___/|_| |_|_|_| |_|___/\__\__,_|_|_|

  Remove browser-desktop kiosk workstation
BANNER
    echo ""
}

###############################################################################
# Restore xrdp backups
###############################################################################

restore_xrdp_backups() {
    log_info "Checking for xrdp configuration backups..."

    local restored=false

    for conf_file in xrdp.ini sesman.ini startwm.sh; do
        # Find the most recent backup
        local latest
        latest="$(ls -t "${XRDP_CONF_DIR}/${conf_file}.bak."* 2>/dev/null | head -n1 || true)"

        if [[ -n "$latest" && -f "$latest" ]]; then
            log_info "Restoring ${conf_file} from backup: ${latest}"
            cp "$latest" "${XRDP_CONF_DIR}/${conf_file}"
            restored=true
        else
            log_warn "No backup found for ${conf_file}"
        fi
    done

    if $restored; then
        log_success "xrdp configuration backups restored"
    else
        log_warn "No xrdp backups were found to restore"
    fi
}

###############################################################################
# Main
###############################################################################

main() {
    show_banner

    # Must be root
    check_root

    # Confirm with user
    echo -n "This will remove browser-desktop and all its configuration. Continue? (y/N): "
    read -r answer
    if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
        log_info "Uninstall cancelled"
        exit 0
    fi

    echo ""

    # Stop xrdp service if running
    log_info "Stopping xrdp service..."
    if systemctl is-active --quiet xrdp 2>/dev/null; then
        systemctl stop xrdp
        log_success "xrdp service stopped"
    else
        log_info "xrdp service is not running"
    fi

    # Remove browser-desktop runtime
    if [[ -d "$BROWSER_DESKTOP_DIR" ]]; then
        log_info "Removing ${BROWSER_DESKTOP_DIR}..."
        rm -rf "$BROWSER_DESKTOP_DIR"
        log_success "Removed ${BROWSER_DESKTOP_DIR}"
    else
        log_info "${BROWSER_DESKTOP_DIR} does not exist; skipping"
    fi

    # Remove browser-desktop configuration
    if [[ -d "$BROWSER_DESKTOP_ETC" ]]; then
        log_info "Removing ${BROWSER_DESKTOP_ETC}..."
        rm -rf "$BROWSER_DESKTOP_ETC"
        log_success "Removed ${BROWSER_DESKTOP_ETC}"
    else
        log_info "${BROWSER_DESKTOP_ETC} does not exist; skipping"
    fi

    # Remove Chrome managed policy
    if [[ -f "$CHROME_POLICY_FILE" ]]; then
        log_info "Removing Chrome managed policy: ${CHROME_POLICY_FILE}"
        rm -f "$CHROME_POLICY_FILE"
        log_success "Removed Chrome managed policy"
    else
        log_info "Chrome managed policy not found; skipping"
    fi

    # Remove browser-desktop-ctl symlink
    if [[ -L "$CTL_SYMLINK" ]]; then
        log_info "Removing symlink: ${CTL_SYMLINK}"
        rm -f "$CTL_SYMLINK"
        log_success "Removed symlink: ${CTL_SYMLINK}"
    else
        log_info "Symlink ${CTL_SYMLINK} not found; skipping"
    fi

    # Restore xrdp configuration backups
    restore_xrdp_backups

    # Warnings
    echo ""
    log_warn "The 'browser-users' group was NOT removed. To remove it manually:"
    echo "     groupdel browser-users"
    echo ""
    log_warn "The following packages remain installed and were NOT removed:"
    echo "     xrdp, Openbox, Google Chrome, Xorg, PulseAudio"
    echo "     Remove them manually if no longer needed."
    echo ""

    log_success "browser-desktop uninstall complete"
}

main "$@"
