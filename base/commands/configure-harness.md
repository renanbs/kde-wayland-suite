---
description: Configures and audits the AI host profile (OMP + Antigravity, Claude Code, Cursor, OpenCode), model role mapping (reasoning, code, review, security), and language preference.
---

# /configure-harness

Manages and audits alignment between the active AI host, model role assignments, and language settings:

```bash
./bin/kde-config configure-harness
```

---

## Guided Configuration Flow (Mandatory for AI Agents)

The agent must detect the active harness and use `AskUserQuestion` (or `ask`) to configure preferences:

### Question 1 — Language Preference (`language`) (singleSelect):
- **"English (en) (Recommended)"** — Standard English for all internal configs, runlogs, and contracts.
- **"Português do Brasil (pt-BR)"** — Brazilian Portuguese user-facing responses translated by the AI agent.

### Question 2 — Reasoning & Architecture Role (`reasoning`) (singleSelect):
- **"google-antigravity/gemini-3.7-flash (Recommended)"** — Ultra-fast, fluid reasoning, massive context window.
- **"google-antigravity/gemini-3.7-pro"** — Deep reasoning and complex architectural decomposition.
- **"anthropic/claude-3.7-sonnet"** — Hybrid reasoning with extended thinking.
- **"deepseek/deepseek-r1"** — Pure algorithmic and logical reasoning.

### Question 3 — Implementation & Code Role (`code`) (singleSelect):
- **"google-antigravity/gemini-3.7-flash (Recommended)"** — Precise execution for shell, C/Rust, and kernel patches.
- **"anthropic/claude-3.7-sonnet"** — Precision engineering for complex refactoring.
- **"openai/gpt-4o"** — Standard multi-tasking.

### Question 4 — Review & Sanity Role (`review`) (singleSelect):
- **"google-antigravity/gemini-3.7-flash (Recommended)"** — Fast output contract validation and regression checks.
- **"anthropic/claude-3.5-haiku"** — Lightweight verification.

### Question 5 — Security & Defense Role (`security`) (singleSelect):
- **"anthropic/claude-3.7-sonnet (Recommended)"** — Rigorous defensive audits, permissions, and hardware security analysis.
- **"google-antigravity/gemini-3.7-flash"** — Fast risk surface scanning.

---

### Mapping Answers to Command Execution:

```bash
./bin/kde-config configure-harness --set <harness> <reasoning> <code> <review> <security> [language]
```

To set language preference directly:
```bash
./bin/kde-config configure-harness --set-lang <en|pt-BR>
```

To auto-sync with the active harness:
```bash
./bin/kde-config configure-harness --sync
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
