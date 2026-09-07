---
description: Diagnoses power and battery consumption (hybrid primary GPU, PCIe ASPM, PCI runtime PM, battery health, idle radios) and applies user-selected optimizations with snapshot reversibility.
---

# /battery

Diagnoses machine power consumption and, based on user decisions, applies targeted optimizations with automatic backup snapshots:

```bash
./bin/kde-config battery-status
```

---

## Mandatory AI Agent Workflow

**Never apply battery optimizations without asking the user first.** This command is diagnostic first, decision second:

1. Run `./bin/kde-config battery-status` and inspect the output.
2. For each actionable finding (`[FAIL]` or `[INFO]`), explain the technical tradeoff (stability, latency, power savings) to the user.
3. Use `AskUserQuestion` (or `ask`) to prompt the user finding-by-finding for what they wish to apply. Never assume "yes" by default.
4. Execute `./bin/kde-config battery-apply` passing only the chosen flags:

```bash
# Example: User only wants primary GPU reordering, no ASPM
BATTERY_FIX_GPU_PRIMARY=1 ./bin/kde-config battery-apply

# Example: User wants GPU fix + PCIe ASPM persisting across reboot
BATTERY_FIX_GPU_PRIMARY=1 BATTERY_FIX_PCIE_ASPM=1 BATTERY_FIX_PCIE_ASPM_PERSIST=1 ./bin/kde-config battery-apply

# Example: User also enables PCI device runtime PM persisting across reboot
BATTERY_FIX_PCI_RUNTIME_PM=1 BATTERY_FIX_PCI_RUNTIME_PM_PERSIST=1 ./bin/kde-config battery-apply
```

5. Inform the user of the snapshot path (saved at `~/.config/kde-config-backups/.battery-latest`) and how to revert:

```bash
./bin/kde-config battery-revert
```

---

## What is Diagnosed and Optimized

- **Compositor Primary GPU (Intel/NVIDIA/AMD hybrid systems):** Detects if KWin is rendering on a GPU different from the one driving the internal panel (eDP), keeping the discrete GPU awake and copying frames unnecessarily. The fix reorders `KWIN_DRM_DEVICES` in `~/.config/plasma-workspace/env/*.sh` to prioritize the panel's GPU while keeping the discrete GPU available for PRIME offload and external displays. Takes effect upon logout/login or reboot.
- **PCIe ASPM:** Detects if PCIe Active State Power Management policy is not set to `powersave`/`powersupersave`. The fix sets `powersave` immediately; optionally persists via systemd service (`BATTERY_FIX_PCIE_ASPM_PERSIST=1`).
- **PCI Device Runtime PM:** Detects devices with `power/control` stuck in `on` (NVMe, Wi-Fi, SATA, PCIe root ports never idling). The fix toggles devices to `auto`; optionally persists via systemd (`BATTERY_FIX_PCI_RUNTIME_PM_PERSIST=1`).
- **Battery Health, Idle Radios (Bluetooth/Docker), CPU Governor:** Informational only (user decisions / hardware limits).

---

## Output Format (Mandatory across all tools)

Always report in these four phases, in this exact order:

### 1. Plan

Before executing any action:

- **Command:** exact command to be executed
- **Action:** concise description of power adjustments applied
- **Reversible:** how to undo — `./bin/kde-config battery-revert`

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
| How to Revert | `./bin/kde-config battery-revert` |
| Requires | `nothing` \| `logout/login` \| `reboot` |

### 4. Recommended Actions (Mandatory if ⚠️ or ❌ occurs)

Whenever **2. Execution** contains any item marked with `⚠️` (warning) or `❌` (failure), provide the exact 1-line command to fix each issue:

- `• <Issue description>`: `exact command to fix`

### Rules

- Never declare success without verification: run the corresponding `status` check or re-read the modified file before marking `✅`.
- If a command requires `sudo` and the session lacks an interactive TTY, prompt the user to execute it with the `!` prefix and show the exact command line.
- Failures must be reported with actual command error output; never omit or soften errors.
- If a fix requires a logout or reboot to take effect, declare it in `Requires` and reiterate in the summary text.
