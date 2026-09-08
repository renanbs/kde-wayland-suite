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
