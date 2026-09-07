---
description: Configures and activates 3 and 4-finger touchpad gestures via libinput-gestures and D-Bus in KDE Plasma 6 Wayland without KWin gesture concurrency conflicts.
---

# /configure-gestures

Installs and reloads touchpad gesture configuration for KDE Plasma 6 Wayland:

```bash
./bin/kde-config gestures
```

---

## Output Format (Mandatory across all tools)

Always report in these four phases, in this exact order:

### 1. Plan

Before executing any action:

- **Command:** `./bin/kde-config gestures`
- **Action:** Configures `~/.config/libinput-gestures.conf` and starts user service
- **Reversible:** Yes (`./bin/kde-config rollback`)

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
| How to Revert | `./bin/kde-config rollback` |
| Requires | `nothing` \| `logout/login` |

### 4. Recommended Actions (Mandatory if ⚠️ or ❌ occurs)

Whenever **2. Execution** contains any item marked with `⚠️` (warning) or `❌` (failure), provide the exact 1-line command to fix each issue:

- `• <Issue description>`: `exact command to fix`

### Rules

- Never declare success without verification: run the corresponding `status` check or re-read the modified file before marking `✅`.
- If a command requires `sudo` and the session lacks an interactive TTY, prompt the user to execute it with the `!` prefix and show the exact command line.
- Failures must be reported with actual command error output; never omit or soften errors.
- If a fix requires a logout or reboot to take effect, declare it in `Requires` and reiterate in the summary text.
