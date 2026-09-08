---
description: Checks for new versions of the suite on GitHub and updates repository, symlinks, and local OMP/Claude marketplaces.
---

# /upgrade

Checks and upgrades the **KDE Plasma 6 Wayland Suite** to the latest release published on GitHub:

```bash
./bin/kde-config upgrade
```

---

## Guided Upgrade Flow (Mandatory for AI Agents)

Before applying the upgrade, the agent must check remote status and use `AskUserQuestion` (or `ask`) to confirm:

### Question 1 — Upgrade Action (singleSelect):
- **"Check and Upgrade Immediately (Recommended)"** — Runs `git pull`, updates symlinks, and syncs plugin in OMP/Claude marketplace.
- **"Check Version Only (Read-Only)"** — Compares local and remote version without modifying system files.

### Mapping Answers to Command Execution:

* **Upgrade Immediately:**
  ```bash
  ./bin/kde-config upgrade --apply
  ```
* **Check Only:**
  ```bash
  ./bin/kde-config upgrade --check
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
