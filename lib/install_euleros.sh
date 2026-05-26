#!/bin/bash
# EulerOS installation script for browser-desktop
# Installs xrdp, Xorg, Openbox, PulseAudio, and Google Chrome via yum

set -e

# Resolve script directory and source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

# Chrome repo configuration for EulerOS / RHEL-based systems
readonly CHROME_REPO_FILE="/etc/yum.repos.d/google-chrome.repo"
readonly CHROME_REPO_CONTENT="[google-chrome]
name=Google Chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub"

# Install base packages: xrdp, Xorg, Openbox, PulseAudio
install_base_packages() {
    log_info "Installing base packages (xrdp, Xorg, Openbox, PulseAudio)..."

    log_info "Enabling EPEL repository..."
    if ! yum install -y epel-release; then
        die "Failed to enable EPEL repository"
    fi

    log_info "Updating yum package index..."
    yum makecache -y

    log_info "Installing xrdp..."
    yum install -y xrdp || die "Failed to install xrdp"

    log_info "Installing Xorg..."
    yum install -y xorg-x11-server-Xorg xorg-x11-xinit || die "Failed to install Xorg"

    log_info "Installing Openbox..."
    yum install -y openbox || die "Failed to install Openbox"

    # PulseAudio installation is optional; warn but do not abort on failure
    log_info "Installing PulseAudio..."
    if yum install -y pulseaudio; then
        log_success "PulseAudio installed successfully"
    else
        log_warn "PulseAudio installation failed; continuing without audio support"
    fi

    log_success "Base packages installed"
}

# Add Chrome repo and install Google Chrome via yum
install_chrome() {
    log_info "Checking Google Chrome installation..."

    # Skip if Chrome is already installed
    if command_exists google-chrome || command_exists google-chrome-stable; then
        log_info "Google Chrome is already installed; skipping"
        return 0
    fi

    # Also check via rpm in case the binary is not yet on PATH
    if rpm -q google-chrome-stable >/dev/null 2>&1; then
        log_info "Google Chrome is already installed (rpm); skipping"
        return 0
    fi

    log_info "Adding Google Chrome yum repository..."
    echo "${CHROME_REPO_CONTENT}" > "${CHROME_REPO_FILE}"

    log_info "Installing Google Chrome via yum..."
    if ! yum install -y google-chrome-stable; then
        die "Failed to install Google Chrome"
    fi

    log_success "Google Chrome installed"
}

# Configure the xrdp service: enable and start
configure_xrdp_service() {
    log_info "Configuring xrdp service..."

    log_info "Enabling xrdp service..."
    systemctl enable xrdp

    log_info "Starting xrdp service..."
    systemctl start xrdp

    log_success "xrdp service configured and started"
}

# Allow RDP port (3389) through the firewall
configure_firewall() {
    log_info "Configuring firewall for RDP (port 3389)..."

    if ! command_exists firewall-cmd; then
        log_warn "firewall-cmd is not installed; skipping firewall configuration"
        return 0
    fi

    # Allow RDP traffic permanently
    firewall-cmd --permanent --add-port=3389/tcp
    firewall-cmd --reload

    log_success "Firewall configured: port 3389 allowed"
}

# Main entry point: orchestrate full EulerOS installation
install_euleros() {
    log_info "Starting EulerOS installation..."

    check_root

    install_base_packages
    install_chrome
    configure_xrdp_service
    configure_firewall

    log_success "EulerOS installation completed successfully"
}

# Allow direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_euleros "$@"
fi
