---
description: Non-destructive hardware inspection and machine profiling for Linux Wayland environments (detects GPUs, displays, Wi-Fi, keyboards, and saves machine-profile.json).
---

# /init (or /scan)

Performs a full, 100% safe and non-destructive inspection of your machine's hardware and environment:
- Identifies OS, kernel, compositor session, active AI host harness, and language preference.
- Inspects power supply, battery health, and charging threshold support.
- Detects GPUs (iGPU / dGPU), KWin DRM devices, and internal display refresh modes (60 Hz vs high Hz).
- Detects wireless interfaces (`wlo1`), drivers, 802.11 power saving state, and PCIe bus runtime PM.
- Detects keyboards (i8042 bus, Tongfang/Avell matrix, external keyboards), touchpad, and Logitech mice.
- Saves the structured profile to:
  `~/.config/linux-wayland-suite/machine-profile.json`

```bash
./bin/linux-wayland-config init
```

---

## Guided Flow (Mandatory for AI Agents)

Before running `init`, the agent **must use `AskUserQuestion` (or `ask`)** to confirm language preference:

### Question 1 — Language Preference (`language`) (singleSelect):
- **"English (en) (Recommended)"** — Standard English. All internal configs, runlogs, and contracts remain canonical English.
- **"Português do Brasil (pt-BR)"** — Brazilian Portuguese. Internal operations remain in English; user-facing dialogue and summaries are localized.

### Next Step After `/init`:
Once `/init` completes and the machine profile is saved:
1. Explain the detected hardware findings to the user.
2. Proceed to `/setup` (`commands/setup.md`) or use `linux-wayland-config setup` to apply user-selected optimizations.

---

## Output Format (Mandatory across all tools)

Always report in these four phases, in this exact order:

### 1. Plan

Before executing any action:

- **Command:** `./bin/linux-wayland-config init`
- **Action:** non-destructive hardware scan and machine profiling
- **Reversible:** not applicable (safe read-only inspection)

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
| Changed | `machine-profile.json generated` |
| Language | saved language (`en` or `pt-BR`) |
| Unchanged | all system files and user configurations |
| Backup | `none (read-only inspection)` |
| Saved Report | `./bin/linux-wayland-config report` |
| How to Revert | `rm ~/.config/linux-wayland-suite/machine-profile.json` |
| Requires | `nothing — run ./bin/linux-wayland-config setup next` |

### 4. Recommended Actions (Mandatory if ⚠️ or ❌ occurs)

Whenever **2. Execution** contains any item marked with `⚠️` (warning) or `❌` (failure), provide the exact 1-line command to fix each issue:

- `• <Issue description>`: `exact command to fix`
