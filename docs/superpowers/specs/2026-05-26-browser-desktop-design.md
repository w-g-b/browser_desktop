# Browser Desktop - Design Specification

**Date**: 2026-05-26  
**Status**: Draft  
**Author**: Auto-generated from brainstorming session

---

## 1. Overview

A minimal Linux desktop system that provides only browser functionality, accessible via xrdp remote desktop connections. Designed as a remote workstation for users who need secure, restricted browser access.

### 1.1 Use Case

Remote workstation: deployed on servers, users connect via RDP client to get a browser-only environment for remote work or secure browsing.

### 1.2 Core Requirements

- **Browser**: Google Chrome / Chromium in kiosk (full-screen) mode
- **Desktop**: No desktop environment — pure kiosk mode
- **Access control**: URL whitelist — only allowed websites are accessible
- **Multi-user**: Multiple users can connect simultaneously, each with isolated browser sessions
- **Remote access**: xrdp (RDP protocol, port 3389)
- **Target systems**: Ubuntu LTS and EulerOS (Huawei enterprise Linux)
- **Deployment**: Shell installation scripts
- **Management**: Simple file-based configuration initially; advanced management features deferred to future iterations

### 1.3 Non-Goals (Deferred)

- Web management console
- Advanced content filtering (beyond URL patterns)
- File transfer / clipboard sharing configuration
- Session recording / auditing
- Custom browser extensions

---

## 2. Architecture

### 2.1 Component Overview

```
┌─────────────────────────────────────────────────────┐
│                  Linux Server                        │
│                                                      │
│  ┌──────────┐    ┌────────────────────────────────┐  │
│  │  xrdp    │───▶│  Xorg (per-session display)    │  │
│  │  :3389   │    │                                │  │
│  └──────────┘    │  ┌──────────┐  ┌────────────┐  │  │
│       │          │  │ Openbox  │  │  PulseAudio │  │  │
│       │          │  │ (minimal)│  │  (optional)  │  │  │
│       │          │  └────┬─────┘  └────────────┘  │  │
│       │          │       │                        │  │
│       │          │       ▼                        │  │
│       │          │  ┌──────────────────────────┐  │  │
│       │          │  │  Chrome --kiosk          │  │  │
│       │          │  │  ┌────────────────────┐   │  │  │
│       │          │  │  │ Enterprise Policy  │   │  │  │
│       │          │  │  │ (URL whitelist)    │   │  │  │
│       │          │  │  └────────────────────┘   │  │  │
│       │          │  └──────────────────────────┘  │  │
│       │          └────────────────────────────────┘  │
│       │                                              │
│  ┌────┴───────────────────────────────────────────┐  │
│  │          Linux System Users                     │  │
│  │  user1 / user2 / user3 ...                     │  │
│  └────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
         ▲
         │ RDP (port 3389)
         │
    ┌────┴────┐
    │  RDP    │
    │  Client │
    └─────────┘
```

### 2.2 Component Selection

| Component | Role | Rationale |
|-----------|------|-----------|
| **xrdp** | RDP server, accepts remote desktop connections | Standard Linux RDP implementation, compatible with Windows RDP clients |
| **Xorg** | Display server, creates independent display per session | xrdp's native Xorg backend, best performance |
| **Openbox** | Minimal window manager | Only manages Chrome window lifecycle — no panels, menus, or decorations |
| **Chrome** | Browser in kiosk full-screen mode | User requirement; enterprise policy supports URL filtering natively |
| **System users** | Multi-user isolation | Each Linux user logs in independently with naturally isolated data |

### 2.3 User Connection Flow

1. User connects to server `IP:3389` using an RDP client
2. xrdp displays login prompt; user enters Linux username/password
3. xrdp starts an independent Xorg display for the user (e.g., `:10`)
4. Session startup script executes → launches Openbox + Chrome kiosk
5. User sees full-screen Chrome, can only access whitelisted websites
6. On disconnect: session persists (reconnectable) or auto-cleans based on configuration

---

## 3. Installation & Deployment

### 3.1 Script Structure

```
install.sh                    # Main entry point, detects OS and dispatches
├── lib/
│   ├── common.sh             # Shared functions (logging, colors, error handling)
│   ├── detect_os.sh          # Distribution detection logic
│   ├── install_ubuntu.sh     # Ubuntu-specific installation
│   ├── install_euleros.sh    # EulerOS-specific installation
│   └── configure.sh          # Common configuration (shared across both systems)
├── config/
│   ├── chrome/               # Chrome enterprise policy files
│   ├── xrdp/                 # xrdp configuration
│   ├── openbox/              # Openbox configuration
│   └── session/              # Session startup scripts
├── portal/                   # Portal homepage files
├── tools/                    # Management tool script
└── templates/
    └── whitelist.conf        # URL whitelist template
```

### 3.2 Distribution Detection

Reads `/etc/os-release`:
- Ubuntu: `ID=ubuntu`
- EulerOS: `ID=euleros` or `ID=openEuler`

### 3.3 Package Mapping

| Function | Ubuntu Package | EulerOS Package |
|----------|---------------|-----------------|
| Display server | `xserver-xorg-core`, `xorgxrdp` | `xorg-x11-server-Xorg`, `xorgxrdp` |
| RDP service | `xrdp` | `xrdp` |
| Window manager | `openbox` | `openbox` |
| Browser | `google-chrome-stable` or `chromium-browser` | `google-chrome-stable` or `chromium` |
| Audio (optional) | `pulseaudio`, `pulseaudio-module-xrdp` | `pulseaudio` |
| Base utilities | `dbus-x11`, `x11-xserver-utils` | `dbus-x11`, `xorg-x11-server-utils` |

### 3.4 Installation Flow

1. Verify root privileges (must run as root)
2. Detect distribution and version
3. Install base dependencies (xrdp, Xorg, Openbox, Chrome)
4. Deploy configuration files (Chrome policies, xrdp config, Openbox config, session scripts)
5. Create system users (if specified)
6. Start and enable xrdp service
7. Configure firewall rules (open port 3389)

---

## 4. Chrome Kiosk Mode & Enterprise Policies

### 4.1 Chrome Launch Command

```bash
exec google-chrome-stable \
  --kiosk \
  --no-first-run \
  --no-default-browser-check \
  --disable-session-crashed-bubble \
  --disable-infobars \
  --disable-features=TranslateUI \
  --disable-component-update \
  --disable-background-networking \
  --disable-sync \
  --disable-popup-blocking \
  --user-data-dir="$HOME/.chrome-kiosk" \
  "file:///opt/browser-desktop/portal/index.html"
```

### 4.2 Enterprise Policy Configuration

Policy file path: `/etc/opt/chrome/policies/managed/browser-desktop.json`

```json
{
  "URLBlocklist": ["*"],
  "URLAllowlist": [
    "https://www.google.com",
    "https://*.google.com",
    "https://github.com",
    "https://*.github.com",
    "file:///opt/browser-desktop/portal/*"
  ],
  "HomepageLocation": "file:///opt/browser-desktop/portal/index.html",
  "RestoreOnStartup": 4,
  "RestoreOnStartupURLs": ["file:///opt/browser-desktop/portal/index.html"],
  "BookmarkBarEnabled": false,
  "EditBookmarksEnabled": false,
  "IncognitoModeAvailability": 2,
  "DeveloperToolsAvailability": 2,
  "AllowDeletingBrowserHistory": false,
  "DownloadRestrictions": 1,
  "DefaultPopupsSetting": 2,
  "PasswordManagerEnabled": false,
  "AutofillAddressEnabled": false,
  "AutofillCreditCardEnabled": false,
  "SafeBrowsingEnabled": true,
  "MetricsReportingEnabled": false
}
```

### 4.3 Key Policy Descriptions

| Policy | Value | Purpose |
|--------|-------|---------|
| `URLBlocklist` | `["*"]` | Block all URLs by default |
| `URLAllowlist` | URL pattern list | Only allow listed websites |
| `IncognitoModeAvailability` | `2` | Force incognito mode (no data retained on close) |
| `DeveloperToolsAvailability` | `2` | Disable DevTools (prevent bypassing restrictions) |
| `DownloadRestrictions` | `1` | Block dangerous downloads |

### 4.4 Portal Page

A local HTML portal page (`/opt/browser-desktop/portal/index.html`) serves as Chrome's homepage:
- Clean card-style navigation listing allowed website links
- Dynamically generates link list from whitelist configuration
- Local file — loads without network access
- Styled with minimal CSS for a professional appearance

### 4.5 Whitelist Configuration

Whitelist stored at `/etc/browser-desktop/whitelist.conf`:

```
# One URL pattern per line
# Supports wildcards: * matches any characters
https://www.google.com
https://*.google.com
https://github.com
https://*.internal-company.com
```

Management script `browser-desktop-ctl`:

```bash
browser-desktop-ctl add-url "https://example.com"     # Add URL to whitelist
browser-desktop-ctl remove-url "https://example.com"   # Remove URL
browser-desktop-ctl list-urls                           # View current whitelist
browser-desktop-ctl apply                               # Regenerate Chrome policy
```

---

## 5. Session Management & Multi-User Support

### 5.1 xrdp Session Entry Point

`/etc/xrdp/startwm.sh`:

```bash
#!/bin/bash
if [ -x "$HOME/.xsession" ]; then
    exec "$HOME/.xsession"
fi
exec /opt/browser-desktop/bin/start-session.sh
```

### 5.2 Session Lifecycle

```
User RDP connection
    │
    ▼
xrdp authenticates username/password
    │
    ▼
xrdp allocates display (:10, :11, ...)
    │
    ▼
Executes startwm.sh
    │
    ▼
┌──────────────────────────┐
│  start-session.sh        │
│  ├─ Set environment vars │
│  ├─ Start dbus           │
│  ├─ Start Openbox (bg)   │
│  └─ exec Chrome (fg)     │
└──────────────────────────┘
    │
    ▼
User operates browser normally
    │
    ├─ Disconnect → session preserved (reconnectable)
    └─ Logout/close → Chrome exits → Openbox exits → session ends
```

### 5.3 Session Configuration

`/etc/browser-desktop/session.conf`:

```ini
[session]
# disconnect_keep: preserve session on disconnect, resume on reconnect
# disconnect_cleanup: clean session data on disconnect
mode=disconnect_keep

# Clean browsing data on exit
cleanup_on_exit=true
```

### 5.4 Multi-User Isolation

- **User creation**: `useradd -m -s /bin/bash browseruser1`
- **User group**: All browser users join `browser-users` group
- **Data isolation**: Each user's Chrome profile lives in their own `~/.chrome-kiosk/`
- **Permission restrictions**:
  - Users can only run Chrome and Openbox — no terminal or other programs
  - Restricted shell via `~/.bashrc`
  - No `sudo` access

### 5.5 User Management Commands

```bash
browser-desktop-ctl add-user <username> [--password <pass>]
browser-desktop-ctl delete-user <username>
browser-desktop-ctl list-users
browser-desktop-ctl reset-user <username>
```

### 5.6 Kiosk Escape Prevention

- Openbox config hides right-click menu and window decorations
- Chrome `chrome://` internal pages disabled (except `chrome://policy` for debugging)
- `file://` protocol disabled via Chrome policy (except portal page)
- System level: users have no shell access, home directory permissions restricted

---

## 6. Project File Structure

### 6.1 Source Repository

```
browser-desktop/
├── install.sh                    # Main installation entry script
├── uninstall.sh                  # Uninstall script
├── lib/
│   ├── common.sh                 # Shared functions (logging, colors, error handling)
│   ├── detect_os.sh              # Distribution detection
│   ├── install_ubuntu.sh         # Ubuntu installation logic
│   ├── install_euleros.sh        # EulerOS installation logic
│   └── configure.sh              # Common configuration deployment
├── config/
│   ├── xrdp/
│   │   ├── xrdp.ini              # xrdp main config (customized login screen)
│   │   ├── sesman.ini            # Session manager config
│   │   └── startwm.sh            # Session entry script
│   ├── openbox/
│   │   ├── rc.xml                # Openbox config (hide decorations/menus)
│   │   └── menu.xml              # Empty menu (disable right-click)
│   ├── chrome/
│   │   └── managed-policy.json   # Chrome enterprise policy template
│   └── session/
│       ├── start-session.sh      # Session startup script
│       └── session.conf          # Session configuration
├── portal/
│   ├── index.html                # Portal homepage
│   ├── css/
│   │   └── portal.css            # Portal styles
│   └── js/
│       └── portal.js             # Portal dynamic link loading logic
├── tools/
│   └── browser-desktop-ctl.sh    # Management tool script
├── templates/
│   └── whitelist.conf            # Whitelist template
└── README.md                     # Project documentation
```

### 6.2 Installed System Layout

```
/opt/browser-desktop/             # Program files
├── bin/
│   ├── start-session.sh
│   └── browser-desktop-ctl
├── portal/
│   ├── index.html
│   ├── css/
│   └── js/
└── lib/
    └── common.sh

/etc/browser-desktop/             # Configuration files
├── whitelist.conf                # URL whitelist
├── session.conf                  # Session configuration
└── browser-desktop.conf          # Global configuration

/etc/opt/chrome/policies/managed/ # Chrome policies (auto-generated)
└── browser-desktop.json

/etc/xrdp/                        # xrdp configuration (overwritten on install)
├── xrdp.ini
├── sesman.ini
└── startwm.sh
```

### 6.3 Global Configuration

`/etc/browser-desktop/browser-desktop.conf`:

```ini
[general]
portal_title=Browser Workstation
language=zh-CN

[session]
mode=disconnect_keep
cleanup_on_exit=true
max_sessions=10

[xrdp]
port=3389
bpp=24
```

---

## 7. Security Considerations

- Users have minimal system privileges — no shell, no sudo
- Chrome runs in forced incognito mode with no data persistence
- Developer tools disabled to prevent policy bypass
- URL filtering via enterprise policy is enforced at the browser level
- xrdp uses TLS encryption for RDP connections
- Firewall limits access to port 3389 only
- Chrome's sandboxing provides additional process isolation

---

## 8. Future Enhancements (Out of Scope for v1)

- Web-based management console for users and whitelist
- Session recording and auditing
- Clipboard sharing configuration
- Printer redirection
- Custom branding/theming for portal page
- LDAP/AD integration for user authentication
- Automated whitelist sync from external source
- Monitoring dashboard (active sessions, resource usage)
