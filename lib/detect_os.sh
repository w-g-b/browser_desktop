#!/bin/bash
# OS detection functions

# Detect Linux distribution
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release

        case "$ID" in
            ubuntu|debian)
                echo "ubuntu"
                ;;
            euleros|openEuler)
                echo "euleros"
                ;;
            *)
                echo "unknown"
                ;;
        esac
    else
        echo "unknown"
    fi
}

# Get distribution version
get_distro_version() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$VERSION_ID"
    else
        echo "unknown"
    fi
}

# Get distribution name (human-readable)
get_distro_name() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$PRETTY_NAME"
    else
        echo "Unknown Linux"
    fi
}

# Check if distribution is supported
is_supported_distro() {
    local distro
    distro=$(detect_distro)

    case "$distro" in
        ubuntu|euleros)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Validate distribution version
validate_distro_version() {
    local distro="$1"
    local version
    version=$(get_distro_version)

    case "$distro" in
        ubuntu)
            # Support Ubuntu 20.04 LTS and 22.04 LTS
            if [[ "$version" == "20.04" || "$version" == "22.04" ]]; then
                return 0
            fi
            ;;
        euleros)
            # Support EulerOS 2.x
            if [[ "$version" =~ ^2\. ]]; then
                return 0
            fi
            ;;
    esac

    return 1
}
