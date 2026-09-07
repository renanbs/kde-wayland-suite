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

## Output Format (Mandatory across all tools)

Always report in these four phases, in this exact order:

### 1. Plan

Before executing:

- **Command:** `./bin/kde-config upgrade --apply`
- **Action:** Fetches latest git commit, relinks CLI, and updates plugin manifest
- **Reversible:** Yes (`git checkout <previous_commit>`)

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
| Previous Version | version before update |
| Updated Version | final version after update |
| Backup | Git commit history preserved |
| Saved Report | `./bin/kde-config report` (or `~/.local/state/kde-wayland-suite/runs/`) |
| How to Revert | `git checkout <previous_commit>` |
| Requires | `nothing` \| `logout/login` \| `reboot` |

### 4. Recommended Actions (Mandatory if ⚠️ or ❌ occurs)

Whenever **2. Execution** contains any item marked with `⚠️` (warning) or `❌` (failure), provide the exact 1-line command to fix each issue:

- `• <Issue description>`: `exact command to fix`
