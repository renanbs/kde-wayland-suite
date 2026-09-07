---
description: Full initialization of the KDE Plasma 6 Wayland environment (language preference, backups, keyboard repair, touchpad gestures, Logitech mouse, battery diagnostic, and CLI setup).
---

# /init

Executes the full initialization and configuration of the KDE Wayland Suite with automatic backups:

```bash
./bin/kde-config init
```

---

## Guided Initialization Flow (Mandatory for AI Agents)

`init` configures multiple components at once. **Never execute `init` blindly.** Before running any command, use the `AskUserQuestion` (or `ask`) tool to collect the user's choices in a single prompt before proceeding:

### Question 1 — Language Preference (`language`) (singleSelect):
- **"English (en) (Recommended)"** — Standard English. All internal configs, runlogs, and contracts remain canonical English.
- **"Português do Brasil (pt-BR)"** — Brazilian Portuguese. Internal operations remain in English; the AI will translate user-facing messages and reports to Portuguese.

### Question 2 — Components (`components`) (multiSelect):
- **"Keyboard, cedilla, and shortcuts (Ctrl+C ABNT2, US-intl native ç)"** — Recommended.
- **"Touchpad gestures (3/4 fingers via libinput-gestures)"** — Recommended if laptop has a touchpad.
- **"Logitech MX Master 3S mouse (logiops / logid)"** — Only if the user uses this mouse.
- **"Battery / power consumption diagnostic"** — Recommended (read-only diagnostic within init; no fixes applied yet).

### Question 3 — Layout Auto-Heal on Login (`autoheal`) (singleSelect):
- **"Yes, protect against KWin/Plasma layout collapse bug (Recommended)"** — Installs an autostart hook that re-applies full keyboard layout (`br,us`) on every login.
- **"No, manual layout management"** — Skips installing the autostart hook.

### Question 4 — AI Host Profile & Model Roles (`harness`):
- Automatically aligns with active host (OMP, Claude Code, Cursor, Antigravity) and configures model role mapping.

---

### Mapping Answers to Command Execution:

```bash
# Example: Language English, user does not have mouse, wants other components and auto-heal
KDE_SUITE_LANG=en SKIP_MOUSE=1 KDE_SUITE_LAYOUT_AUTOHEAL=1 ./bin/kde-config init

# Example: Language pt-BR, user only wants keyboard and battery diagnostic
KDE_SUITE_LANG=pt-BR SKIP_GESTURES=1 SKIP_MOUSE=1 ./bin/kde-config init
```

The environment variables `KDE_SUITE_LANG`, `SKIP_KEYBOARD`, `SKIP_GESTURES`, `SKIP_MOUSE`, and `SKIP_BATTERY` control each stage.
The selected language is permanently saved to `~/.config/linux-wayland-suite/harness-profile.json`.

### Battery: Diagnostic Inside `init`, Fixes Applied Separately

When "Battery / power consumption diagnostic" is selected, `init` only runs `battery-status` (safe read-only inspection). **Never** pass `BATTERY_FIX_*` during `init`. Once `init` completes and the diagnostics are visible, follow the `/battery` flow (`commands/battery.md`): explain findings to the user, prompt for confirmation via `AskUserQuestion`, and only then execute `./bin/kde-config battery-apply` with corresponding variables.

---

## Output Format (Mandatory across all tools)

Always report in these four phases, in this exact order:

### 1. Plan

Before executing any action:

- **Command:** the exact command line to be executed
- **Action:** one concise sentence explaining what changes in the system
- **Reversible:** how to undo — or `not applicable` for read-only actions

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
| Language | saved language (`en` or `pt-BR`) |
| Unchanged | what was skipped or declined, and why |
| Backup | snapshot path, or `none` |
| Saved Report | `./bin/kde-config report` (or `~/.local/state/kde-wayland-suite/runs/`) |
| How to Revert | the exact reversal command line |
| Requires | `nothing` \| `logout/login` \| `reboot` |

### 4. Recommended Actions (Mandatory if ⚠️ or ❌ occurs)

Whenever **2. Execution** contains any item marked with `⚠️` (warning) or `❌` (failure), provide the exact 1-line command to fix each issue:

- `• <Issue description>`: `exact command to fix`

### Rules

- Never declare success without verification: run the corresponding `status` check or re-read the modified file before marking `✅`.
- If a command requires `sudo` and the session lacks an interactive TTY, prompt the user to execute it with the `!` prefix and show the exact command line.
- Failures must be reported with actual command error output; never omit or soften errors.
- If a fix requires a logout or reboot to take effect, declare it in `Requires` and reiterate in the summary text.
