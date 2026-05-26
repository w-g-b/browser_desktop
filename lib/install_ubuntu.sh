#!/bin/bash
# Ubuntu installation script for browser-desktop
# Installs xrdp, Xorg, Openbox, PulseAudio, and Google Chrome

set -e

# Resolve script directory and source common library
# Use unique variable name to avoid overwriting caller's SCRIPT_DIR when sourced
_UBUNTU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${_UBUNTU_DIR}/common.sh"

# Chrome download URL (stable amd64)
readonly CHROME_DEB_URL="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
readonly CHROME_DEB_FILE="/tmp/google-chrome-stable_current_amd64.deb"

# Install base packages: xrdp, Xorg, Openbox, PulseAudio
install_base_packages() {
    log_info "Installing base packages (xrdp, Xorg, Openbox, PulseAudio)..."

    wait_for_lock

    log_info "Updating apt package index..."
    apt-get update -y

    log_info "Installing xrdp..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y xrdp

    log_info "Installing Xorg..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y xorg

    log_info "Installing Openbox..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y openbox

    # PulseAudio installation is optional; warn but do not abort on failure
    log_info "Installing PulseAudio..."
    if DEBIAN_FRONTEND=noninteractive apt-get install -y pulseaudio; then
        log_success "PulseAudio installed successfully"
    else
        log_warn "PulseAudio installation failed; continuing without audio support"
    fi

    log_success "Base packages installed"
}

# Download and install Google Chrome
install_chrome() {
    log_info "Checking Google Chrome installation..."

    # Skip if Chrome is already installed
    if command_exists google-chrome || command_exists google-chrome-stable; then
        log_info "Google Chrome is already installed; skipping"
        return 0
    fi

    # Also check via dpkg in case the binary is not yet on PATH
    if dpkg -l google-chrome-stable 2>/dev/null | grep -q '^ii'; then
        log_info "Google Chrome is already installed (dpkg); skipping"
        return 0
    fi

    log_info "Downloading Google Chrome from ${CHROME_DEB_URL}..."
    if ! wget -q -O "${CHROME_DEB_FILE}" "${CHROME_DEB_URL}"; then
        die "Failed to download Google Chrome"
    fi

    log_info "Installing Google Chrome..."
    wait_for_lock
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y "${CHROME_DEB_FILE}"; then
        # Attempt to fix missing dependencies
        log_warn "Fixing missing dependencies..."
        DEBIAN_FRONTEND=noninteractive apt-get install -f -y || \
            die "Failed to install Google Chrome dependencies"
        DEBIAN_FRONTEND=noninteractive apt-get install -y "${CHROME_DEB_FILE}" || \
            die "Failed to install Google Chrome"
    fi

    # Clean up downloaded .deb
    rm -f "${CHROME_DEB_FILE}"

    log_success "Google Chrome installed"
}

# Configure the xrdp service: ssl-cert group, enable and start
configure_xrdp_service() {
    log_info "Configuring xrdp service..."

    # Add xrdp user to ssl-cert group so it can read TLS certificates
    if getent group ssl-cert >/dev/null 2>&1; then
        log_info "Adding xrdp user to ssl-cert group..."
        usermod -aG ssl-cert xrdp
    else
        log_warn "ssl-cert group not found; skipping group membership"
    fi

    log_info "Enabling xrdp service..."
    systemctl enable xrdp

    log_info "Starting xrdp service..."
    systemctl start xrdp

    log_success "xrdp service configured and started"
}

# Allow RDP port (3389) through the firewall
configure_firewall() {
    log_info "Configuring firewall for RDP (port 3389)..."

    if ! command_exists ufw; then
        log_warn "ufw is not installed; skipping firewall configuration"
        return 0
    fi

    # Allow RDP traffic
    ufw allow 3389/tcp
    log_success "Firewall configured: port 3389 allowed"
}

# Main entry point: orchestrate full Ubuntu installation
install_ubuntu() {
    log_info "Starting Ubuntu installation..."

    check_root

    install_base_packages
    install_chrome
    configure_xrdp_service
    configure_firewall

    log_success "Ubuntu installation completed successfully"
}

# Allow direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_ubuntu "$@"
fi
