---
name: linux-wayland-suite
description: Comprehensive Linux Wayland configuration suite for KDE Plasma, GNOME, and multi-vendor hardware: keyboard shortcuts repair, Tongfang/Avell/Clevo matrix unlocking, smart dynamic keyboard power management, native cedilla on US-intl via the native pt_BR compose table (LC_CTYPE, no input method), Wayland clipboard repair, 3/4-finger touchpad gestures, Logitech MX Master 3S button/scroll configuration via logiops, and battery/power diagnostics.
---

# Linux Wayland Suite (Input, Hardware & Desktop Automation)
This skill provides automations and diagnostics to resolve common problems in the input stack and clipboard of **KDE Plasma 6 (Wayland)**:

1. **Keyboard Shortcut Repair (`Ctrl+C` on ABNT2)**: Eliminates legacy `im-cedilla` module that grabs keystrokes and breaks `Ctrl+C` under Wayland.
2. **Native Cedilla on US-intl (`dead_acute + c` $\to$ `ç` in Chrome, Orca IDE, Electron, GTK, Qt)**: Achieved **without any input method**. The system compose table for pt_BR (`/usr/share/X11/locale/pt_BR.UTF-8/Compose`) natively maps `<dead_acute> <c>` to `ç`. The suite configures `LC_CTYPE=pt_BR.UTF-8` in `~/.config/environment.d/cedilla.conf` (+ `systemd --user set-environment` and `~/.config/fish/conf.d/cedilla.fish`), and injects `--ozone-platform-hint=auto` into `*-flags.conf` for Chrome/Chromium/Brave/Orca/Code/Electron.
3. **Wayland Clipboard Deadlock Repair (`Ctrl+Shift+V` / Images)**: Cleans up zombie `xsel` processes and ensures native `wl-clipboard` (`wl-copy`/`wl-paste`) operation in Konsole and shells.
4. **Portable Touchpad Gestures**: Maps 3 and 4-finger gestures complementary to KWin via `libinput-gestures` and D-Bus (`qdbus6`), without concurrency conflicts with native Plasma gestures.
5. **General Diagnostics and Verification**: Real-time auditing of session state, active layouts, clipboard health, browser flags, composition validation, and daemon status.
6. **Logitech MX Master 3S (`logiops`/`logid`)**: Installs `logiops`, generates `~/.config/logid.cfg` (symlinked to `/etc/logid.cfg`, editable without sudo), maps the thumb gesture button to workspace switching / Overview / Show Desktop, and locks SmartShift into free-spin scrolling. Also enables `kwinrc [Windows] PerOutputVirtualDesktops=true` for multi-monitor setups.
7. **Battery and Power Diagnostics & Optimization**: `diagnose-battery.sh` audits compositor primary GPU on hybrid Intel/NVIDIA/AMD laptops, PCIe ASPM policies, PCI runtime power management, battery health, and idle radios (read-only). `configure-battery.sh` applies user-selected fixes (`BATTERY_FIX_GPU_PRIMARY`, `BATTERY_FIX_PCIE_ASPM`, `BATTERY_FIX_PCIE_ASPM_PERSIST`, `BATTERY_FIX_PCI_RUNTIME_PM`, `BATTERY_FIX_PCI_RUNTIME_PM_PERSIST`) with automatic backup snapshots; `revert-battery.sh` rolls back snapshots.
8. **KWin `kxkbrc` Collapse Bug Detection**: `check-status.sh` detects when Plasma overwrote `~/.config/kxkbrc` retaining only the layout active at logout time. `fix-keyboard.sh` repairs the file immediately and can optionally install an autostart hook (`KDE_SUITE_LAYOUT_AUTOHEAL=1`) to re-apply the dual layout on every login.
9. **System-wide Ctrl Key Lockup Prevention**: Prevents keymap compilation failures when `LayoutList` and `VariantList` element counts mismatch during live KWin reloads.
10. **fcitx5 Key Grabbing Deactivation**: Masks system-level autostarts (`/etc/xdg/autostart/org.fcitx.Fcitx5.desktop`) with `Hidden=true` in `~/.config/autostart/` to prevent fcitx5 from swallowing Ctrl combinations under Wayland.
11. **Tongfang / Avell / Clevo Hardware Matrix Fix**: Unlocks the physical Control/Fn matrix on Tongfang chassis via GRUB kernel parameters (`i8042.nopnp=1 i8042.nomux=1 i8042.reset=1 acpi_osi='Windows 2020'`).
12. **Smart Dynamic Keyboard Power Management (`smart-keyboard-power`)**: Dynamic udev rule (`/etc/udev/rules.d/90-kde-smart-keyboard-power.rules`) keeping `power/control = on` (zero latency) when standalone, and switching to `auto` (power saver) when external keyboards connect.
13. **Tongfang S3 Deep Sleep Resume Fix**: Hook in `/etc/systemd/system-sleep/90-kde-keyboard-resume.sh` issuing `rescan` to `/sys/devices/platform/i8042/serio0/drvctl` upon lid open.
14. **Structured Event Logs and Historical Reporting**: Every execution records a run in `~/.local/state/kde-wayland-suite/runs/<timestamp>-<cmd>/` with `events.tsv`, `output.log`, and `meta.env`. `report` parses structured events to produce reproducible reports and actionable remediation advice.

> **Standardized Output Format**: Every command in this suite reports in the 4-phase format defined in `OUTPUT-CONTRACT.md` (**Plan** $\to$ **Execution** $\to$ **Summary** $\to$ **Recommended Actions**), identical across Claude Code, Cursor, OMP, OpenCode, and Antigravity.

> **Internationalization & Translation**: Internally, all commands, skills, contracts, and runlogs are maintained in English. The AI agent translates explanations and interaction dialogues into the user's selected language (`en` or `pt-BR`) as configured.

---

## Guided `init` Workflow (Mandatory for AI Agents)

`init` configures multiple subsystems at once (language, keyboard, gestures, mouse, power, harness). **Never run `init` blindly.** Before executing any command, use `AskUserQuestion` (or `ask`) to prompt the user with all questions in a single turn:

### Question 1 — Language Preference (`language`) (singleSelect):
- **"English (en) (Recommended)"** — Standard English. Internal operations remain canonical English.
- **"Português do Brasil (pt-BR)"** — Brazilian Portuguese. Internal operations remain in English; the AI will translate user-facing messages and reports to Portuguese.

### Question 2 — Components (`components`) (multiSelect):
- **"Keyboard, cedilla, and shortcuts (Ctrl+C ABNT2, US-intl native ç)"** — Recommended.
- **"Touchpad gestures (3/4 fingers via libinput-gestures)"** — Recommended if touchpad is present.
- **"Logitech MX Master 3S mouse (logiops / logid)"** — Only if the user has this mouse.
- **"Battery / power consumption diagnostic"** — Recommended (read-only diagnostic within init; no fixes applied yet).

### Question 3 — Layout Auto-Heal on Login (`autoheal`) (singleSelect):
- **"Yes, protect against KWin/Plasma layout collapse bug (Recommended)"** — Installs autostart hook that re-applies dual layout on every login.
- **"No, manual layout management"** — Skips autostart hook.

### Question 4 — AI Host Profile & Model Roles (`harness`):
- Automatically aligns with active host (OMP, Claude Code, Cursor, Antigravity) and configures model role mapping.

### Mapping Answers to Command Execution:

```bash
# Example: Language English, user does not have mouse, wants other components and auto-heal
KDE_SUITE_LANG=en SKIP_MOUSE=1 KDE_SUITE_LAYOUT_AUTOHEAL=1 ./bin/kde-config init

# Example: Language pt-BR, user only wants keyboard and battery diagnostic
KDE_SUITE_LANG=pt-BR SKIP_GESTURES=1 SKIP_MOUSE=1 ./bin/kde-config init
```

The environment variables `KDE_SUITE_LANG`, `SKIP_KEYBOARD`, `SKIP_GESTURES`, `SKIP_MOUSE`, and `SKIP_BATTERY` control each stage. The selected language is saved in `~/.config/linux-wayland-suite/harness-profile.json`.

### Battery: Diagnostic Inside `init`, Fixes Applied Separately

`init` only runs `battery-status` (read-only). **Never pass `BATTERY_FIX_*` during `init`**. Once diagnostics appear in the output, explain findings to the user and prompt with `AskUserQuestion` to decide which optimizations to apply, only then executing `./bin/kde-config battery-apply` with corresponding flags.

---

## Available Scripts & Commands

| Script / Command | Description |
| :--- | :--- |
| `shared/check-status.sh` | Full audit of environment, keyboard, native cedilla, Wayland clipboard, IM variables, gestures |
| `shared/fix-keyboard.sh` | Repairs `Ctrl+C`, native US-intl cedilla, clipboard deadlocks, hot-reloads KWin |
| `shared/configure-gestures.sh` | Setup of `libinput-gestures.conf` and service restart |
| `shared/configure-mouse.sh` | Installs `logiops` and configures MX Master 3S (gesture button, SmartShift) |
| `shared/diagnose-battery.sh` | Read-only battery/power diagnostics: primary GPU, PCIe ASPM, battery health, idle radios |
| `shared/configure-battery.sh` | Applies user-chosen battery optimizations (`BATTERY_FIX_*`) with backup snapshot |
| `shared/revert-battery.sh` | Reverts the last application of `configure-battery.sh` (or specific snapshot) |
| `shared/fix-tongfang.sh` | Unlocks keyboard matrix on Tongfang/Avell/Clevo laptops via GRUB |
| `shared/test-keyboard.py` | Interactive real-time key event monitor (/dev/input/eventX) |
| `shared/monitor-irq.py` | Hardware electric pulse monitor on IRQ 1 (i8042 keyboard) |
| `shared/manage-keyboard-power.sh` | Dynamic keyboard power management (on standalone, auto with USB/BT keyboard) |
| `shared/preflight-base.sh` | Preflight checks for environment, DMI hardware, Plasma version, and D-Bus tools |
| `bin/kde-config switch [br\|us]` | Immediate keyboard layout switching via D-Bus |
| `bin/kde-config set-lang [en\|pt-BR]` | Saves user language preference |

---

## Quick CLI Usage

```bash
# Full diagnostic
./bin/kde-config status

# Set language preference
./bin/kde-config set-lang en

# Apply keyboard, cedilla, and clipboard fix
./bin/kde-config fix-keyboard

# Unlock keyboard matrix on Tongfang/Avell laptops (GRUB)
./bin/kde-config fix-tongfang

# Monitor key events in real time
./bin/kde-config test-keyboard

# Monitor electric pulses on IRQ 1 (i8042)
./bin/kde-config monitor-irq

# Enable dynamic smart keyboard power management
./bin/kde-config smart-keyboard-power --apply

# Apply touchpad gestures
./bin/kde-config gestures

# Configure Logitech MX Master 3S mouse
./bin/kde-config mouse

# Battery / power diagnostic (read-only)
./bin/kde-config battery-status

# Apply user-selected battery fix
BATTERY_FIX_GPU_PRIMARY=1 ./bin/kde-config battery-apply

# Revert last battery optimization
./bin/kde-config battery-revert

# Switch active layout
./bin/kde-config switch br
./bin/kde-config switch us
```
