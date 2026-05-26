#!/bin/bash
# Configuration deployment script for browser-desktop
# Deploys xrdp, Openbox, Chrome policy, and browser-desktop runtime files

set -e

# Resolve script directory and project root
# Use unique variable names to avoid overwriting caller's SCRIPT_DIR when sourced
_CONFIGURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$_CONFIGURE_DIR")"

# shellcheck source=common.sh
source "${_CONFIGURE_DIR}/common.sh"

# Installation paths
readonly XRDP_CONF_DIR="/etc/xrdp"
readonly OPENBOX_CONF_DIR="/etc/xdg/openbox"
readonly BROWSER_DESKTOP_DIR="/opt/browser-desktop"
readonly BROWSER_DESKTOP_ETC="/etc/browser-desktop"
readonly CHROME_POLICY_DIR="/etc/opt/chrome/policies/managed"
readonly CTL_SYMLINK="/usr/local/bin/browser-desktop-ctl"

###############################################################################
# Deploy xrdp configuration
###############################################################################

deploy_xrdp_config() {
    log_info "Deploying xrdp configuration..."

    ensure_dir "$XRDP_CONF_DIR"

    # Install xrdp.ini
    install_file \
        "${PROJECT_DIR}/config/xrdp/xrdp.ini" \
        "${XRDP_CONF_DIR}/xrdp.ini" \
        0644

    # Install sesman.ini
    install_file \
        "${PROJECT_DIR}/config/xrdp/sesman.ini" \
        "${XRDP_CONF_DIR}/sesman.ini" \
        0644

    # Install startwm.sh (must be executable)
    install_file \
        "${PROJECT_DIR}/config/xrdp/startwm.sh" \
        "${XRDP_CONF_DIR}/startwm.sh" \
        0755

    log_success "xrdp configuration deployed"
}

###############################################################################
# Deploy Openbox configuration
###############################################################################

deploy_openbox_config() {
    log_info "Deploying Openbox configuration..."

    ensure_dir "$OPENBOX_CONF_DIR"

    # Install rc.xml
    install_file \
        "${PROJECT_DIR}/config/openbox/rc.xml" \
        "${OPENBOX_CONF_DIR}/rc.xml" \
        0644

    # Install menu.xml
    install_file \
        "${PROJECT_DIR}/config/openbox/menu.xml" \
        "${OPENBOX_CONF_DIR}/menu.xml" \
        0644

    log_success "Openbox configuration deployed"
}

###############################################################################
# Deploy browser-desktop runtime
###############################################################################

deploy_browser_desktop() {
    log_info "Deploying browser-desktop runtime to ${BROWSER_DESKTOP_DIR}..."

    # Create directory structure
    ensure_dir "${BROWSER_DESKTOP_DIR}/bin"
    ensure_dir "${BROWSER_DESKTOP_DIR}/portal/css"
    ensure_dir "${BROWSER_DESKTOP_DIR}/portal/js"
    ensure_dir "${BROWSER_DESKTOP_DIR}/lib"
    ensure_dir "${BROWSER_DESKTOP_DIR}/config"
    ensure_dir "$BROWSER_DESKTOP_ETC"

    # Install session startup script
    install_file \
        "${PROJECT_DIR}/config/session/start-session.sh" \
        "${BROWSER_DESKTOP_DIR}/bin/start-session.sh" \
        0755

    # Install portal HTTP server
    install_file \
        "${PROJECT_DIR}/tools/portal-server.sh" \
        "${BROWSER_DESKTOP_DIR}/bin/portal-server.sh" \
        0755

    # Install portal files
    install_file \
        "${PROJECT_DIR}/portal/index.html" \
        "${BROWSER_DESKTOP_DIR}/portal/index.html" \
        0644

    install_file \
        "${PROJECT_DIR}/portal/css/portal.css" \
        "${BROWSER_DESKTOP_DIR}/portal/css/portal.css" \
        0644

    install_file \
        "${PROJECT_DIR}/portal/js/portal.js" \
        "${BROWSER_DESKTOP_DIR}/portal/js/portal.js" \
        0644

    # Install common library (needed by browser-desktop-ctl at runtime)
    install_file \
        "${PROJECT_DIR}/lib/common.sh" \
        "${BROWSER_DESKTOP_DIR}/lib/common.sh" \
        0644

    # Install session configuration
    install_file \
        "${PROJECT_DIR}/config/session/session.conf" \
        "${BROWSER_DESKTOP_ETC}/session.conf" \
        0644

    # Install whitelist template (only if not already present)
    if [[ ! -f "${BROWSER_DESKTOP_ETC}/whitelist.conf" ]]; then
        install_file \
            "${PROJECT_DIR}/templates/whitelist.conf" \
            "${BROWSER_DESKTOP_ETC}/whitelist.conf" \
            0644
    else
        log_info "Whitelist already exists at ${BROWSER_DESKTOP_ETC}/whitelist.conf; preserving"
    fi

    # Install Chrome policy template (used by apply command)
    install_file \
        "${PROJECT_DIR}/config/chrome/managed-policy.json" \
        "${BROWSER_DESKTOP_DIR}/config/managed-policy.json" \
        0644

    # Install management tool
    install_file \
        "${PROJECT_DIR}/tools/browser-desktop-ctl.sh" \
        "${BROWSER_DESKTOP_DIR}/bin/browser-desktop-ctl.sh" \
        0755

    # Create symlink for browser-desktop-ctl
    if [[ -L "$CTL_SYMLINK" || -f "$CTL_SYMLINK" ]]; then
        rm -f "$CTL_SYMLINK"
    fi
    ln -s "${BROWSER_DESKTOP_DIR}/bin/browser-desktop-ctl.sh" "$CTL_SYMLINK"
    log_info "Created symlink: ${CTL_SYMLINK} -> ${BROWSER_DESKTOP_DIR}/bin/browser-desktop-ctl.sh"

    log_success "browser-desktop runtime deployed"
}

###############################################################################
# Deploy Chrome managed policy
###############################################################################

deploy_chrome_policy() {
    log_info "Deploying Chrome managed policy..."

    ensure_dir "$CHROME_POLICY_DIR"

    install_file \
        "${PROJECT_DIR}/config/chrome/managed-policy.json" \
        "${CHROME_POLICY_DIR}/browser-desktop.json" \
        0644

    log_success "Chrome managed policy deployed"
}

###############################################################################
# Main deployment orchestrator
###############################################################################

deploy_configuration() {
    log_info "Starting full configuration deployment..."

    deploy_xrdp_config
    deploy_openbox_config
    deploy_browser_desktop
    deploy_chrome_policy

    # Run apply to regenerate Chrome policy and portal from whitelist
    log_info "Running browser-desktop-ctl apply..."
    if [[ -x "${BROWSER_DESKTOP_DIR}/bin/browser-desktop-ctl.sh" ]]; then
        "${BROWSER_DESKTOP_DIR}/bin/browser-desktop-ctl.sh" apply
    else
        log_warn "browser-desktop-ctl not found or not executable; skipping apply"
    fi

    log_success "All configuration deployed successfully"
}

# Allow direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_root
    deploy_configuration
fi
