#!/bin/bash
# Test and verification script for browser-desktop
# Checks file existence, permissions, syntax, and basic functionality

set -e

# Resolve script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Counters
PASS=0
FAIL=0

# Result markers
OK="✓"
NO="✗"

###############################################################################
# Helpers
###############################################################################

check_pass() {
    echo -e "  ${OK} $1"
    PASS=$((PASS + 1))
}

check_fail() {
    echo -e "  ${NO} $1"
    FAIL=$((FAIL + 1))
}

check_file_exists() {
    local file="$1"
    local desc="${2:-$file}"
    if [[ -f "${SCRIPT_DIR}/${file}" ]]; then
        check_pass "$desc exists"
    else
        check_fail "$desc missing (${file})"
    fi
}

check_executable() {
    local file="$1"
    local desc="${2:-$file}"
    if [[ -x "${SCRIPT_DIR}/${file}" ]]; then
        check_pass "$desc is executable"
    else
        check_fail "$desc is not executable (${file})"
    fi
}

check_bash_syntax() {
    local file="$1"
    local desc="${2:-$file}"
    if bash -n "${SCRIPT_DIR}/${file}" 2>/dev/null; then
        check_pass "$desc syntax OK"
    else
        check_fail "$desc syntax error (${file})"
    fi
}

check_json_valid() {
    local file="$1"
    local desc="${2:-$file}"
    if python3 -c "import json; json.load(open('${SCRIPT_DIR}/${file}'))" 2>/dev/null || \
       python -c "import json; json.load(open('${SCRIPT_DIR}/${file}'))" 2>/dev/null; then
        check_pass "$desc valid JSON"
    else
        check_fail "$desc invalid JSON (${file})"
    fi
}

###############################################################################
# Tests
###############################################################################

echo ""
echo "========================================="
echo "  browser-desktop Verification Tests"
echo "========================================="
echo ""

# -------------------------------------------------------
echo "1. File Existence Checks"
echo "-----------------------------------------"

# Core scripts
check_file_exists "install.sh"              "install.sh"
check_file_exists "uninstall.sh"            "uninstall.sh"
check_file_exists "README.md"               "README.md"

# Libraries
check_file_exists "lib/common.sh"           "lib/common.sh"
check_file_exists "lib/detect_os.sh"        "lib/detect_os.sh"
check_file_exists "lib/install_ubuntu.sh"   "lib/install_ubuntu.sh"
check_file_exists "lib/install_euleros.sh"  "lib/install_euleros.sh"
check_file_exists "lib/configure.sh"        "lib/configure.sh"

# Configuration
check_file_exists "config/xrdp/xrdp.ini"       "xrdp.ini"
check_file_exists "config/xrdp/sesman.ini"      "sesman.ini"
check_file_exists "config/xrdp/startwm.sh"      "startwm.sh"
check_file_exists "config/openbox/rc.xml"        "rc.xml"
check_file_exists "config/openbox/menu.xml"      "menu.xml"
check_file_exists "config/chrome/managed-policy.json" "managed-policy.json"
check_file_exists "config/session/session.conf"  "session.conf"
check_file_exists "config/session/start-session.sh" "start-session.sh"

# Portal
check_file_exists "portal/index.html"       "portal/index.html"
check_file_exists "portal/css/portal.css"   "portal/css/portal.css"
check_file_exists "portal/js/portal.js"     "portal/js/portal.js"

# Templates and tools
check_file_exists "templates/whitelist.conf"    "whitelist.conf template"
check_file_exists "tools/browser-desktop-ctl.sh" "browser-desktop-ctl.sh"

echo ""

# -------------------------------------------------------
echo "2. Executable Permissions"
echo "-----------------------------------------"

check_executable "install.sh"                   "install.sh"
check_executable "uninstall.sh"                 "uninstall.sh"
check_executable "lib/configure.sh"             "lib/configure.sh"
check_executable "lib/install_ubuntu.sh"        "lib/install_ubuntu.sh"
check_executable "lib/install_euleros.sh"       "lib/install_euleros.sh"
check_executable "config/xrdp/startwm.sh"       "startwm.sh"
check_executable "config/session/start-session.sh" "start-session.sh"
check_executable "tools/browser-desktop-ctl.sh"  "browser-desktop-ctl.sh"

echo ""

# -------------------------------------------------------
echo "3. Bash Syntax Checks (bash -n)"
echo "-----------------------------------------"

for script in \
    install.sh \
    uninstall.sh \
    lib/common.sh \
    lib/detect_os.sh \
    lib/install_ubuntu.sh \
    lib/install_euleros.sh \
    lib/configure.sh \
    config/xrdp/startwm.sh \
    config/session/start-session.sh \
    tools/browser-desktop-ctl.sh; do
    check_bash_syntax "$script" "$script"
done

echo ""

# -------------------------------------------------------
echo "4. JSON Validation"
echo "-----------------------------------------"

check_json_valid "config/chrome/managed-policy.json" "managed-policy.json"

echo ""

# -------------------------------------------------------
echo "5. Functional Check: browser-desktop-ctl help"
echo "-----------------------------------------"

help_output=""
if help_output="$(bash "${SCRIPT_DIR}/tools/browser-desktop-ctl.sh" help 2>&1)"; then
    if echo "$help_output" | grep -q "browser-desktop-ctl"; then
        check_pass "browser-desktop-ctl help runs and shows usage"
    else
        check_fail "browser-desktop-ctl help ran but output unexpected"
    fi
else
    check_fail "browser-desktop-ctl help failed"
fi

echo ""

# -------------------------------------------------------
# Summary
echo "========================================="
echo "  Results: ${PASS} passed, ${FAIL} failed"
echo "========================================="
echo ""

if [[ $FAIL -gt 0 ]]; then
    echo "SOME TESTS FAILED"
    exit 1
else
    echo "ALL TESTS PASSED"
    exit 0
fi
