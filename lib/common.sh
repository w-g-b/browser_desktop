#!/bin/bash
# Common utility functions for browser-desktop installation

# Include guard: prevent re-sourcing when loaded by multiple scripts
[[ -n "${_COMMON_SH_LOADED:-}" ]] && return 0
_COMMON_SH_LOADED=1

set -e

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Error handling
die() {
    log_error "$@"
    exit 1
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        die "This script must be run as root (use sudo)"
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Wait for package manager lock
wait_for_lock() {
    local max_attempts=30
    local attempt=0

    while [[ $attempt -lt $max_attempts ]]; do
        if ! fuser /var/lib/dpkg/lock >/dev/null 2>&1 && \
           ! fuser /var/lib/apt/lists/lock >/dev/null 2>&1 && \
           ! fuser /var/cache/apt/archives/lock >/dev/null 2>&1; then
            return 0
        fi

        attempt=$((attempt + 1))
        log_warn "Package manager is locked, waiting... ($attempt/$max_attempts)"
        sleep 2
    done

    die "Package manager remained locked after $max_attempts attempts"
}

# Backup file if it exists
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local backup="${file}.bak.$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup"
        log_info "Backed up $file to $backup"
    fi
}

# Create directory with parent directories
ensure_dir() {
    local dir="$1"
    local mode="${2:-0755}"

    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        chmod "$mode" "$dir"
        log_info "Created directory: $dir"
    fi
}

# Install file with backup
install_file() {
    local src="$1"
    local dest="$2"
    local mode="${3:-0644}"

    backup_file "$dest"
    cp "$src" "$dest"
    chmod "$mode" "$dest"
    log_info "Installed: $dest"
}

# Generate random password
generate_password() {
    local length="${1:-16}"
    openssl rand -base64 48 | tr -dc 'a-zA-Z0-9!@#$%^&*' | head -c "$length"
}
