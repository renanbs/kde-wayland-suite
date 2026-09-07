---
description: Installs logiops and configures Logitech MX Master 3S in KDE Plasma 6 Wayland — thumb gesture button for workspace switching / Overview and SmartShift locked to free-spin mode.
---

# /configure-mouse

Installs `logiops` (if needed), generates `~/.config/logid.cfg`, symlinks to `/etc/logid.cfg`, and activates `logid.service` for the Logitech MX Master 3S:

```bash
./bin/kde-config mouse
```

## What is Configured

- **Thumb Gesture Button:** Hold + swipe left/right switches workspace (`Meta+Ctrl+Left/Right` without moving the active window), up/tap = Overview (`Meta+W`), down = Show Desktop (`Meta+D`).
- **Multi-Monitor:** Enables `Switch desktops independently for each screen` in KWin, ensuring thumb workspace switching works properly on multi-monitor setups.
- **Scroll Wheel:** SmartShift disabled, locked to smooth free-spin mode. Press the physical mode-switch button below the scroll wheel once after setup to lock free-spin mode.
- Editable without sudo at `~/.config/logid.cfg` — after editing, run `sudo systemctl restart logid.service` to reload.

---

## Output Format (Mandatory across all tools)

Always report in these four phases, in this exact order:

### 1. Plan

Before executing any action:

- **Command:** `./bin/kde-config mouse`
- **Action:** Configures `logid.cfg`, links to `/etc/logid.cfg`, and enables systemd service
- **Reversible:** Yes (`sudo systemctl stop logid.service && sudo rm -f /etc/logid.cfg`)

### 2. Execution

One line per step with the corresponding result marker:

- `✅ <step>` — completed and verified
- `⏭️ <step>` — skipped (state reason)
- `⚠️ <step>` — completed with caveats / warning (state reason)
- `❌ <step>` — failed (include actual error output, never paraphrase)

### 3. Summary

Always at the end, even when no system state changed:

| Field | Content |
| :--- | :--- |
| Changed | objective list of changes, or `nothing — already compliant` |
| Unchanged | what was skipped or declined, and why |
| Backup | snapshot path, or `none` |
| Saved Report | `./bin/kde-config report` (or `~/.local/state/kde-wayland-suite/runs/`) |
| How to Revert | `sudo systemctl stop logid.service && sudo rm -f /etc/logid.cfg` |
| Requires | `nothing` |

### 4. Recommended Actions (Mandatory if ⚠️ or ❌ occurs)

Whenever **2. Execution** contains any item marked with `⚠️` (warning) or `❌` (failure), provide the exact 1-line command to fix each issue:

- `• <Issue description>`: `exact command to fix`

### Rules

- Never declare success without verification: run the corresponding `status` check or re-read the modified file before marking `✅`.
- If a command requires `sudo` and the session lacks an interactive TTY, prompt the user to execute it with the `!` prefix and show the exact command line.
- Failures must be reported with actual command error output; never omit or soften errors.
- If a fix requires a logout or reboot to take effect, declare it in `Requires` and reiterate in the summary text.
