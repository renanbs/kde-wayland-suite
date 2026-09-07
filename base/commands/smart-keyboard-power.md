---
description: Dynamically manages integrated keyboard bus power (i8042/serio0) to eliminate Left Ctrl latency and latching without draining battery when an external USB/Bluetooth keyboard is plugged in.
---

# /smart-keyboard-power

Manages the Runtime Power Management state of the integrated keyboard's `serio0` port:
- **Standalone laptop:** Maintains `power/control = "on"` (bus always awake, zero latency, eliminating Left Ctrl latency/latch).
- **With external keyboard (USB/Bluetooth):** Automatically switches to `power/control = "auto"` to maximize battery savings while typing on the external keyboard.

```bash
./bin/kde-config smart-keyboard-power --apply
```

---

## Guided Configuration Flow (Mandatory for AI Agents)

Before applying changes, the agent **must use `AskUserQuestion` (or `ask`)** to collect user preference:

### Question 1 — Keyboard Power Policy (singleSelect):
- **"Smart Dynamic (Recommended)"** — Installs udev rule keeping `on` when used standalone and `auto` when external keyboard is attached.
- **"Always Active ('on' continuous)"** — Forces static `power/control = on` without dynamic switching rule.
- **"Disable / Linux Default ('auto')"** — Removes udev rule and restores default Linux power management.

### Mapping Answers to Command Execution:

* **Smart Dynamic:**
  ```bash
  ./bin/kde-config smart-keyboard-power --apply
  ```
* **Disable / Revert:**
  ```bash
  ./bin/kde-config smart-keyboard-power --remove
  ```
* **Query Current State:**
  ```bash
  ./bin/kde-config smart-keyboard-power --status
  ```

---

## Output Format (Mandatory across all tools)

Always report in these four phases, in this exact order:

### 1. Plan

Before executing any action:

- **Command:** exact command to be executed
- **Action:** concise description of udev rules and power control adjustments
- **Reversible:** how to undo — `./bin/kde-config smart-keyboard-power --remove`

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
| How to Revert | `./bin/kde-config smart-keyboard-power --remove` |
| Requires | `nothing` |

### 4. Recommended Actions (Mandatory if ⚠️ or ❌ occurs)

Whenever **2. Execution** contains any item marked with `⚠️` (warning) or `❌` (failure), provide the exact 1-line command to fix each issue:

- `• <Issue description>`: `exact command to fix`

### Rules

- Never declare success without verification: run the corresponding `status` check or re-read the modified file before marking `✅`.
- If a command requires `sudo` and the session lacks an interactive TTY, prompt the user to execute it with the `!` prefix and show the exact command line.
- Failures must be reported with actual command error output; never omit or soften errors.
