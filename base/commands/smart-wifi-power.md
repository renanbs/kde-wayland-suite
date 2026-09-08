---
description: Dynamically manages Wi-Fi 802.11 power saving and PCIe runtime PM to prevent radio sleep, latency and packet timeouts on AC power while preserving battery savings on battery.
---

# /smart-wifi-power

Manages the dynamic power state of wireless network interfaces (`iwlwifi`, `rtw88`, `mt7921e`, etc.):
- **Connected to AC (Charger):** Disables 802.11 power saving (`power_save off`) and keeps PCIe bus awake (`power/control = on`), eliminating radio sleep intervals, beacon loss, and timeouts for incoming connections (Orca IDE, SSH, remote access).
- **On Battery:** Enables 802.11 power saving (`power_save on`) and PCIe runtime PM (`power/control = auto`) for maximum battery life.
- **On Resume / Re-association:** NetworkManager dispatcher and systemd-sleep hooks ensure the correct power profile is re-applied immediately upon network reconnect or lid open.

```bash
./bin/linux-wayland-config smart-wifi-power --apply
```

---

## Guided Configuration Flow (Mandatory for AI Agents)

Before applying changes, the agent **must use `AskUserQuestion` (or `ask`)** to collect user preference:

### Question 1 — Wi-Fi Power Management Policy (singleSelect):
- **"Smart Dynamic (Recommended)"** — Installs udev rules, NetworkManager dispatcher, and sleep hook to keep Wi-Fi at peak performance on AC and maximum savings on battery.
- **"Status Check Only"** — Safely inspects current power source, 802.11 power save state, and bus power without changing configuration.
- **"Disable / Linux Default"** — Removes dynamic rules and restores default system behavior (`power_save on`).

### Mapping Answers to Command Execution:

* **Smart Dynamic:**
  ```bash
  ./bin/linux-wayland-config smart-wifi-power --apply
  ```
* **Status Check Only:**
  ```bash
  ./bin/linux-wayland-config smart-wifi-power --status
  ```
* **Disable / Revert:**
  ```bash
  ./bin/linux-wayland-config smart-wifi-power --remove
  ```
* **Instant Sync (AC vs Battery):**
  ```bash
  ./bin/linux-wayland-config smart-wifi-power --sync
  ```

---

## Output Format (Mandatory across all tools)

Always report in these four phases, in this exact order:

### 1. Plan

Before executing any action:

- **Command:** exact command to be executed
- **Action:** concise description of udev rules, NetworkManager dispatcher, and sleep hooks
- **Reversible:** how to undo — `./bin/linux-wayland-config smart-wifi-power --remove`

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
| Unchanged | network credentials, SSIDs, and desktop environment configs |
| Backup | `none (new system automation rules)` |
| Saved Report | `./bin/linux-wayland-config report` |
| How to Revert | `./bin/linux-wayland-config smart-wifi-power --remove` |
| Requires | `nothing (takes effect immediately)` |

### 4. Recommended Actions (Mandatory if ⚠️ or ❌ occurs)

Whenever **2. Execution** contains any item marked with `⚠️` (warning) or `❌` (failure), provide the exact 1-line command to fix each issue:

- `• <Issue description>`: `exact command to fix`

### Rules

- Never declare success without verification: run the corresponding `status` check or re-read the modified files before marking `✅`.
- If a command requires `sudo` and the session lacks an interactive TTY, prompt the user to execute it with the `!` prefix and show the exact command line.
- Failures must be reported with actual command error output; never omit or soften errors.
