---
description: Unlocks integrated keyboard and modifier matrix (physical Control key) on Tongfang, Avell, Clevo, and Tuxedo laptops via kernel i8042 and ACPI parameters in GRUB.
---

# /fix-tongfang

Applies the necessary kernel boot parameters so the `i8042` driver and ACPI DSDT correctly process the complete keyboard matrix (including the physical Left Control key) on Tongfang / Avell / Clevo chassis:

```bash
./bin/kde-config fix-tongfang
```

### What the command executes:
1. Identifies hardware via DMI (`/sys/class/dmi/id/`).
2. Creates an automatic backup of `/etc/default/grub` at `/etc/default/grub.bak-tongfang`.
3. Injects parameters `i8042.nopnp=1 i8042.nomux=1 i8042.reset=1 acpi_osi='Windows 2020'` into `GRUB_CMDLINE_LINUX_DEFAULT`.
4. Updates GRUB image via `update-grub` / `grub-mkconfig`.
5. Emits structured events to runlog for verification by `report`.

### To revert:
```bash
./bin/kde-config revert-tongfang
```

---

## Output Format (Mandatory across all tools)

Always report in these four phases, in this exact order:

### 1. Plan

Before executing any action:

- **Command:** `./bin/kde-config fix-tongfang`
- **Action:** Injects i8042/ACPI kernel boot parameters in GRUB to unlock keyboard matrix
- **Reversible:** Yes (`./bin/kde-config revert-tongfang`)

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
| Backup | `/etc/default/grub.bak-tongfang` |
| Saved Report | `./bin/kde-config report` (or `~/.local/state/kde-wayland-suite/runs/`) |
| How to Revert | `./bin/kde-config revert-tongfang` |
| Requires | `reboot` |

### 4. Recommended Actions (Mandatory if ⚠️ or ❌ occurs)

Whenever **2. Execution** contains any item marked with `⚠️` (warning) or `❌` (failure), provide the exact 1-line command to fix each issue:

- `• <Issue description>`: `exact command to fix`

### Rules

- Never declare success without verification: run the corresponding `status` check or re-read the modified file before marking `✅`.
- If a command requires `sudo` and the session lacks an interactive TTY, prompt the user to execute it with the `!` prefix and show the exact command line.
- Failures must be reported with actual command error output; never omit or soften errors.
- If a fix requires a logout or reboot to take effect, declare it in `Requires` and reiterate in the summary text.
