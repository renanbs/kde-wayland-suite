---
description: Runs full health status audit of KDE Plasma 6 Wayland (session, ABNT2/US-intl keyboard, native cedilla, fcitx5 status, touchpad gestures, battery, and AI host alignment).
---

# /check-status

Executes the unified health diagnostic audit of the KDE Wayland environment:

```bash
./bin/kde-config status
```

---

## Output Format (Mandatory across all tools)

Always report in these four phases, in this exact order:

### 1. Plan

Before executing any action:

- **Command:** `./bin/kde-config status`
- **Action:** Audits session, D-Bus, keyboard matrix, IME variables, gestures, power, and AI host alignment
- **Reversible:** `not applicable` (read-only audit)

### 2. Execution

One line per step with the corresponding result marker:

- `✅ <step>` — verified and compliant
- `⏭️ <step>` — skipped
- `⚠️ <step>` — warning / non-compliant setting detected
- `❌ <step>` — failure detected

### 3. Summary

Always at the end:

| Field | Content |
| :--- | :--- |
| Changed | `nothing — read-only status check` |
| Unchanged | full audit completed |
| Backup | `none` |
| Saved Report | `./bin/kde-config report` (or `~/.local/state/kde-wayland-suite/runs/`) |
| How to Revert | `not applicable` |
| Requires | `nothing` |

### 4. Recommended Actions (Mandatory if ⚠️ or ❌ occurs)

Whenever **2. Execution** contains any item marked with `⚠️` (warning) or `❌` (failure), provide the exact 1-line command to fix each issue:

- `• <Issue description>`: `exact command to fix`

### Rules

- Never declare success without verification: run the corresponding `status` check or re-read the modified file before marking `✅`.
- If a command requires `sudo` and the session lacks an interactive TTY, prompt the user to execute it with the `!` prefix and show the exact command line.
- Failures must be reported with actual command error output; never omit or soften errors.
- If a fix requires a logout or reboot to take effect, declare it in `Requires` and reiterate in the summary text.
