# Browser Desktop

A secure, RDP-based browser kiosk workstation for remote access to web applications. Users connect via any RDP client and get a locked-down Chrome browser that only allows access to administrator-approved URLs.

## Features

- **RDP-based access** - Connect from any RDP client (Windows, macOS, Linux, mobile)
- **URL whitelist** - Only administrator-approved sites are accessible
- **Kiosk mode** - Chrome runs fullscreen with no address bar, tabs, or navigation
- **Portal landing page** - Card-based portal for quick access to allowed applications
- **Multi-user support** - Create isolated kiosk users with individual sessions
- **Enterprise policy** - Chrome managed policies enforce security restrictions
- **Session persistence** - Sessions survive disconnect and reconnect
- **Easy management** - Single `browser-desktop-ctl` command for all administration

## Architecture

```
+-------------------+       RDP (3389)       +---------------------------+
|                   | =====================> |        xrdp               |
|   RDP Client      |                        |  (session manager)        |
|  (Windows/Mac/    |                        +---------------------------+
|   Linux/Mobile)   |                        |        Xorg               |
|                   |                        |  (display server :10)     |
+-------------------+                        +---------------------------+
                                             |       Openbox             |
                                             |  (window manager)         |
                                             +---------------------------+
                                             |   Google Chrome           |
                                             |  (kiosk + enterprise      |
                                             |   policy + whitelist)     |
                                             +---------------------------+
                                             |    Portal Page            |
                                             |  (file:///opt/browser-    |
                                             |   desktop/portal/)        |
                                             +---------------------------+
```

**Flow:**
1. User connects via RDP client to port 3389
2. xrdp authenticates the user and starts an Xorg session
3. Openbox window manager launches in kiosk mode (no decorations)
4. Chrome starts fullscreen, loading the portal page
5. User clicks a portal card to navigate to an allowed URL
6. Chrome enterprise policy blocks any URL not on the whitelist

## Quick Start

### Installation

```bash
# Clone or copy the project to the target server
cd browser-desktop

# Run the installer (must be root)
sudo ./install.sh
```

### Create a Kiosk User

```bash
# Auto-generate a password
sudo browser-desktop-ctl add-user kiosk1

# Or specify a password
sudo browser-desktop-ctl add-user kiosk1 --password "MySecurePass123"
```

### Add Allowed URLs

```bash
sudo browser-desktop-ctl add-url "https://app.example.com"
sudo browser-desktop-ctl add-url "https://*.google.com"
```

### Apply Configuration

```bash
sudo browser-desktop-ctl apply
```

### Connect via RDP

Use any RDP client to connect to `server-ip:3389`. Log in with the kiosk user credentials.

## Configuration

### URL Whitelist

The whitelist is stored at `/etc/browser-desktop/whitelist.conf`. Each line is one URL pattern:

```
# Comments start with #
https://www.google.com
https://*.google.com
https://app.example.com
https://*.example.com/path/*
```

After editing, run `browser-desktop-ctl apply` to regenerate the Chrome policy and portal page.

### Session Configuration

Session behavior is configured at `/etc/browser-desktop/session.conf`:

```ini
[session]
# disconnect_keep    - Preserve session on disconnect
# disconnect_cleanup - Clean session data on disconnect
mode=disconnect_keep

# Clean browsing data on browser exit
cleanup_on_exit=true

# Maximum concurrent sessions
max_sessions=10

# Session timeout in seconds (0 = no timeout)
idle_timeout=0
```

### Chrome Enterprise Policy

The base Chrome policy template is at `/opt/browser-desktop/config/managed-policy.json`. The `apply` command merges whitelist URLs into the policy and writes the result to `/etc/opt/chrome/policies/managed/browser-desktop.json`.

Key policy settings:
- All URLs blocked by default (`URLBlocklist: ["*"]`)
- Only whitelisted URLs allowed (`URLAllowlist`)
- Incognito mode disabled
- Developer tools disabled
- Downloads restricted
- Password manager disabled
- Bookmarks disabled
- Sync disabled

## Management Commands

All management is done via `browser-desktop-ctl`:

| Command | Description |
|---|---|
| `browser-desktop-ctl add-url <url>` | Add a URL to the whitelist |
| `browser-desktop-ctl remove-url <url>` | Remove a URL from the whitelist |
| `browser-desktop-ctl list-urls` | List all whitelisted URLs |
| `browser-desktop-ctl add-user <name>` | Create a kiosk user (auto password) |
| `browser-desktop-ctl add-user <name> --password <pass>` | Create a kiosk user with password |
| `browser-desktop-ctl delete-user <name>` | Delete a kiosk user |
| `browser-desktop-ctl list-users` | List all kiosk users |
| `browser-desktop-ctl reset-user <name>` | Reset a user's Chrome profile |
| `browser-desktop-ctl apply` | Regenerate Chrome policy and portal page |
| `browser-desktop-ctl help` | Show help message |

## Security Features

- **URL filtering** - Chrome enterprise policy blocks all URLs except those explicitly whitelisted
- **Kiosk lockdown** - No address bar, no tabs, no right-click context menu, no keyboard shortcuts to escape
- **No downloads** - File downloads are restricted by policy
- **No extensions** - Extension installation is blocked
- **No incognito** - Incognito mode is disabled to prevent bypassing history/policy
- **No dev tools** - Developer tools are disabled to prevent policy manipulation
- **Session isolation** - Each user has a separate Chrome profile directory
- **Profile cleanup** - Browsing data can be automatically cleaned on session exit
- **Minimal window manager** - Openbox runs with no decorations, no desktop menu, and no taskbar

## File Locations

| Path | Description |
|---|---|
| `/opt/browser-desktop/` | Runtime installation directory |
| `/opt/browser-desktop/bin/` | Executable scripts |
| `/opt/browser-desktop/portal/` | Portal web page (HTML/CSS/JS) |
| `/opt/browser-desktop/lib/` | Shared libraries |
| `/opt/browser-desktop/config/` | Configuration templates |
| `/etc/browser-desktop/` | System configuration |
| `/etc/browser-desktop/whitelist.conf` | URL whitelist |
| `/etc/browser-desktop/session.conf` | Session configuration |
| `/etc/opt/chrome/policies/managed/browser-desktop.json` | Chrome enterprise policy |
| `/etc/xrdp/xrdp.ini` | xrdp server configuration |
| `/etc/xrdp/sesman.ini` | xrdp session manager configuration |
| `/etc/xrdp/startwm.sh` | xrdp session startup script |
| `/etc/xdg/openbox/rc.xml` | Openbox window manager configuration |
| `/usr/local/bin/browser-desktop-ctl` | Management tool symlink |

## Troubleshooting

### Cannot connect via RDP

```bash
# Check xrdp is running
sudo systemctl status xrdp

# Check port 3389 is listening
sudo ss -tlnp | grep 3389

# Check firewall
sudo ufw status          # Ubuntu
sudo firewall-cmd --list-all  # EulerOS

# Check xrdp logs
sudo tail -f /var/log/xrdp.log
sudo tail -f /var/log/xrdp-sesman.log
```

### Chrome does not start or shows a blank screen

```bash
# Check if Chrome is installed
google-chrome --version

# Check xrdp session logs
cat ~/.xsession-errors

# Verify startwm.sh is executable
ls -la /etc/xrdp/startwm.sh

# Verify portal page exists
ls -la /opt/browser-desktop/portal/index.html
```

### URL whitelist not working

```bash
# Check the generated Chrome policy
cat /etc/opt/chrome/policies/managed/browser-desktop.json

# Verify whitelist configuration
cat /etc/browser-desktop/whitelist.conf

# Re-apply configuration
sudo browser-desktop-ctl apply

# Restart xrdp to pick up changes
sudo systemctl restart xrdp
```

### User cannot log in

```bash
# Verify user exists and is in browser-users group
id <username>

# Check user is in the correct group
getent group browser-users

# Reset user password
sudo passwd <username>

# Reset user's Chrome profile
sudo browser-desktop-ctl reset-user <username>
```

### Black screen after login

```bash
# Verify Openbox is installed
which openbox

# Verify session startup script
ls -la /opt/browser-desktop/bin/start-session.sh

# Check for missing dependencies
ldd /opt/browser-desktop/bin/start-session.sh
```

## Uninstallation

```bash
sudo ./uninstall.sh
```

The uninstaller will:
1. Prompt for confirmation
2. Stop the xrdp service
3. Remove `/opt/browser-desktop` and `/etc/browser-desktop`
4. Remove the Chrome managed policy
5. Remove the `browser-desktop-ctl` symlink
6. Restore xrdp configuration from backups

**Note:** The `browser-users` group is NOT automatically removed. Installed packages (xrdp, Openbox, Chrome) are also left in place.

## Requirements

- **OS:** Ubuntu 20.04/22.04 LTS or EulerOS 2.x
- **Privileges:** Root access required for installation
- **Network:** Port 3389 (RDP) must be accessible
- **Memory:** Minimum 2 GB RAM recommended
- **Disk:** Minimum 2 GB free space for packages and runtime
