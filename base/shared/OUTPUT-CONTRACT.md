# Standardized Output Contract

Canonical source for the report format that **every** command/skill in this suite
must follow across **all** tools (Claude Code, Cursor, OMP, OpenCode,
Antigravity). The block below is mirrored at the end of each command and skill
`.md` file. When updating here, replicate across all markdown command templates.

The goal is for the same operation to produce the same structured report
regardless of the host tool used, ensuring the user can compare executions and
always understand what changed, what was skipped, and how to revert.

> **Internationalization Note:** Internal contracts, command specifications,
> and event logs are strictly defined in English. The AI agent translates
> user-facing messages into the user's selected language (e.g. `pt-BR`)
> whenever communicating with the user.

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
| Unchanged | what was skipped or declined, and why |
| Backup | snapshot path, or `none` |
| Saved Report | `./bin/kde-config report` (or `~/.local/state/kde-wayland-suite/runs/`) |
| How to Revert | the exact reversal command line |
| Requires | `nothing` \| `logout/login` \| `reboot` |

### 4. Recommended Actions (Mandatory if ⚠️ or ❌ occurs)

Whenever **2. Execution** contains any item marked with `⚠️` (warning) or `❌` (failure), add this section immediately following **3. Summary**, providing the exact 1-line command to resolve each issue:

- `• <Issue description>`: `exact command to fix`

### Rules & Failure Discipline

- **Never declare success without verification:** run the corresponding `status` check or re-read the modified file before marking `✅`.
- **Explicit Failure Reporting:** Any action that failed, was rejected by a kernel driver, or could not be completed MUST be marked with `❌`. NEVER soften or mask a failure as a warning (`⚠️`) or skip (`⏭️`).
- **Prominent User Notification:** Whenever an operation fails, the AI agent MUST prominently and unambiguously state in the response text that the action **FAILED** and that **NO CHANGE was applied** to that component, explaining the exact technical reason.
- **Sudo Command Guidelines:** When an operation requires root privileges and cannot be executed in a non-interactive subshell, instruct the user to run `linux-wayland-config <subcommand>` directly in their terminal. **Do not prepend `sudo`**, because `sudo`'s `secure_path` often omits `~/.local/bin`. The script internally handles elevation via `exec sudo "$0" "$@"` using its fully-resolved path.
- **Requires field:** If a fix requires a logout or reboot to take effect, declare it in `Requires` and reiterate in the summary text.
