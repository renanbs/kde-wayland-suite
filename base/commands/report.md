---
description: Interactively presents the list of recorded execution runlogs and displays the chosen report with structured events, metrics, and actionable recommendations.
---

# /report

Displays detailed execution reports derived from **structured runlog events** persisted to disk:

```bash
./bin/kde-config report
```

---

## Mandatory Interactive Workflow for AI Agents

When triggered via `/report`, the AI agent **must not simply dump the latest report blindly**. The agent **must**:

1. **Fetch recent history:** List directories in `~/.local/state/kde-wayland-suite/runs/` and retrieve timestamp, command, and event counts (`ok`, `warn`, `fail`).
2. **Present interactive selection:** Use `AskUserQuestion` (or `ask`) listing the 5 to 10 most recent runs for the user to choose.
3. **Render the selected report:** Display the complete run details following the 4-phase contract.

---

## Output Format (Mandatory across all tools)

Always report in these four phases, in this exact order:

### 1. Plan

Before executing:

- **Command:** `./bin/kde-config report <index>`
- **Action:** Displays structured audit trail and remediation advice for selected execution
- **Reversible:** `not applicable` (read-only)

### 2. Execution

List of events from the selected report:

- `✅ <event/step>` — successfully validated
- `⏭️ <event/step>` — skipped
- `⚠️ <event/step>` — warning / non-compliant state
- `❌ <event/step>` — failure recorded

### 3. Summary

Always at the end:

| Field | Content |
| :--- | :--- |
| Selected Report | run directory identifier or index |
| Execution Balance | counts of ok, warnings, and failures |
| Backup | snapshot path, or `none` |
| Saved Report | `./bin/kde-config report <number>` (or `~/.local/state/kde-wayland-suite/runs/`) |
| How to Revert | reversal command or `not applicable` |
| Requires | `nothing` \| `logout/login` \| `reboot` |

### 4. Recommended Actions (Mandatory if ⚠️ or ❌ occurs)

Whenever **2. Execution** contains any item marked with `⚠️` (warning) or `❌` (failure), provide the exact 1-line command to fix each issue:

- `• <Issue description>`: `exact command to fix`
