---
description: Fixes shortcut issues (Ctrl+C) on ABNT2 layout, removes legacy IM variables, and configures native dead-key cedilla on US-intl for Chrome, Orca IDE, Electron, GTK, and Qt in KDE Wayland.
---

# /fix-keyboard

Applies the atomic fix for keyboard shortcuts, layout definitions, native cedilla (`' + c` $\to$ `ç`), and Wayland clipboard:

```bash
./bin/kde-config fix-keyboard
```

Before executing, ask the user if they want to enable **layout auto-heal on login**: KDE Plasma has a known bug where ending a session can overwrite `~/.config/kxkbrc` retaining only the active layout at logout time (the `br` layout disappears and the layout switch widget vanishes from the panel). If the user wants automatic protection across every reboot, run with the environment variable enabled:

```bash
KDE_SUITE_LAYOUT_AUTOHEAL=1 ./bin/kde-config fix-keyboard
```

This installs an autostart entry that reapplies the full dual layout (`br,us`) on each login. If declined, run without the variable — the command still repairs `kxkbrc` immediately.

---

## Output Format (Mandatory across all tools)

Always report in these four phases, in this exact order:

### 1. Plan

Before executing any action:

- **Command:** exact command to be executed
- **Action:** concise explanation of changes to keyboard config, IM modules, and compose rules
- **Reversible:** how to undo — snapshot restoration command

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
