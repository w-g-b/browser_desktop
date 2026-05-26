#!/bin/bash
# Main installation script for browser-desktop
# Entry point that detects OS, dispatches to OS-specific installer,
# deploys configuration, and optionally creates a kiosk user.

set -e

# Resolve script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck source=lib/detect_os.sh
source "${SCRIPT_DIR}/lib/detect_os.sh"
# shellcheck source=lib/configure.sh
source "${SCRIPT_DIR}/lib/configure.sh"

###############################################################################
# Banner and Usage
###############################################################################

show_banner() {
    cat <<'BANNER'
 ____                                    ____              _
| __ ) _ __ _____      _____  ___ _ __  |  _ \  ___  ___ | |_
|  _ \| '__/ _ \ \ /\ / / __|/ _ \ '__| | | | |/ _ \/ _ \| __|
| |_) | | | (_) \ V  V /\__ \  __/ |    | |_| |  __/ (_) | |_
|____/|_|  \___/ \_/\_/ |___/\___|_|    |____/ \___|\___/ \__|

  Secure browser kiosk workstation - RDP-based remote access
BANNER
    echo ""
}

show_usage() {
    cat <<USAGE
Usage: $(basename "$0") [OPTIONS]

Install and configure the browser-desktop kiosk workstation.

Options:
  --create-user <username>   Create a kiosk user after installation
  --password <password>      Password for the new kiosk user (used with --create-user)
  --chrome-package <path>    Install Chrome from a local .deb/.rpm file or directory
                             (required in air-gapped / offline environments)
  -h, --help                 Show this help message

Examples:
  sudo $(basename "$0")
  sudo $(basename "$0") --create-user kiosk1
  sudo $(basename "$0") --create-user kiosk1 --password "secret123"
  sudo $(basename "$0") --chrome-package /tmp/google-chrome-stable_current_amd64.deb
  sudo $(basename "$0") --chrome-package /opt/chrome-packages/
USAGE
}

###############################################################################
# Main
###############################################################################

main() {
    local create_user=""
    local user_password=""
    CHROME_PACKAGE=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --create-user)
                create_user="${2:-}"
                if [[ -z "$create_user" ]]; then
                    die "--create-user requires a username"
                fi
                shift 2
                ;;
            --password)
                user_password="${2:-}"
                if [[ -z "$user_password" ]]; then
                    die "--password requires a value"
                fi
                shift 2
                ;;
            --chrome-package)
                CHROME_PACKAGE="${2:-}"
                if [[ -z "$CHROME_PACKAGE" ]]; then
                    die "--chrome-package requires a file or directory path"
                fi
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    show_banner

    # Must be root
    check_root

    # Detect distribution
    local distro
    distro="$(detect_distro)"
    local distro_name
    distro_name="$(get_distro_name)"

    log_info "Detected OS: ${distro_name}"

    # Validate distribution
    case "$distro" in
        ubuntu)
            log_info "Dispatching to Ubuntu installer..."
            # shellcheck source=lib/install_ubuntu.sh
            source "${SCRIPT_DIR}/lib/install_ubuntu.sh"
            install_ubuntu
            ;;
        euleros)
            log_info "Dispatching to EulerOS installer..."
            # shellcheck source=lib/install_euleros.sh
            source "${SCRIPT_DIR}/lib/install_euleros.sh"
            install_euleros
            ;;
        *)
            die "Unsupported distribution: ${distro_name}. Supported: Ubuntu 20.04/22.04, EulerOS 2.x"
            ;;
    esac

    # Deploy all configuration files
    deploy_configuration

    # Optionally create a kiosk user
    if [[ -n "$create_user" ]]; then
        log_info "Creating kiosk user: ${create_user}"
        if [[ -n "$user_password" ]]; then
            browser-desktop-ctl add-user "$create_user" --password "$user_password"
        else
            browser-desktop-ctl add-user "$create_user"
        fi
    fi

    # Done
    echo ""
    log_success "============================================"
    log_success "  Installation Complete!"
    log_success "============================================"
    echo ""
    log_info "Next steps:"
    echo "  1. Add allowed URLs:"
    echo "     browser-desktop-ctl add-url \"https://example.com\""
    echo ""
    echo "  2. Create kiosk users:"
    echo "     browser-desktop-ctl add-user <username>"
    echo ""
    echo "  3. Apply configuration:"
    echo "     browser-desktop-ctl apply"
    echo ""
    echo "  4. Connect via RDP to port 3389"
    echo ""
}

main "$@"
