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

## Standard Output Format (Evidence-First Verdict)

Every command response must follow this structured, evidence-based format:

### 🎯 Verdict: [ ✅ SUCCESS | ❌ FAILURE | ⚠️ PARTIAL SUCCESS ]
*One clear sentence summarizing the real, observable outcome of the operation.*

---

#### 📋 Execution Breakdown:
* **✅ Applied Successfully:**
  - `<Component Name>`: Concise description of exact changes made and verified.
* **❌ Failure / Hardware Rejection:**
  - `<Component Name>`: **NOT APPLIED**.
    - **Raw Driver / Command Error:** `<exact error output or exit reason>`
    - **Technical Root Cause:** `<hardware/kernel explanation>`
    - **System Impact:** `<confirm system safely remained in prior valid state>`
* **🔒 Manual Permission Required (Root):**
  - `<Component Name>`: Explanation of why elevation could not run in the non-interactive agent subshell.

---

#### 🔬 Technical Evidence & Ground Truth:
| Component | Verified State | Observable Proof / Command | How to Revert |
| :--- | :--- | :--- | :--- |
| `<Name>` | `<Active / Inactive>` | `<Command and exact verified output>` | `<Exact 1-line reversal command>` |

---

#### 💡 Daily Impact & Practical Benefits:
* **<Impact Details>:** Clear explanation of what changes in user experience and workflow.

---

#### 👉 Action Required (Mandatory if manual action, ⚠️ or ❌ occurs):
```bash
linux-wayland-config <subcommand>
```
*(Execution note: run directly in your terminal without typing sudo; elevation is requested internally using the fully-resolved path).*

---

### Rules & Failure Discipline (Inviolable)

1. **Never declare success without verification:** Run the corresponding `status` check or re-read the modified system file before marking `✅`.
2. **Explicit Failure Reporting:** Any action that failed, timed out, was rejected by a kernel driver, or could not be completed MUST be marked with `❌`. NEVER soften or mask a failure as a warning (`⚠️`) or skip (`⏭️`).
3. **Prominent User Notification:** Whenever an operation fails, the AI agent MUST prominently and unambiguously state in the narrative that the action **FAILED** and that **NO CHANGE was applied** to that component, explaining the exact technical reason.
4. **Sudo Command Guidelines:** When an operation requires root privileges and cannot be executed in a non-interactive subshell, instruct the user to run `linux-wayland-config <subcommand>` directly in their terminal. **Do not prepend `sudo`**, because `sudo`'s `secure_path` often omits `~/.local/bin`. The script internally handles elevation via `exec sudo "$0" "$@"` using its fully-resolved path.
5. **Requires field:** If a fix requires a logout or reboot to take effect, explicitly state it in both the breakdown and the daily impact text.
