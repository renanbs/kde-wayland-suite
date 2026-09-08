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
