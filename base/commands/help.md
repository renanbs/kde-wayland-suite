---
description: Displays the full reference manual of commands, shortcuts, solutions, and guided workflows for the KDE Plasma 6 Wayland suite.
---

# /help

Displays the quick reference help center for all commands available in the **KDE Plasma 6 Wayland Suite**:

```bash
./bin/kde-config help
```

---

## Unified Command & Solutions Matrix

| CLI Command | Slash Command | Function / Action | When to Use |
| :--- | :--- | :--- | :--- |
| `./bin/kde-config status` | `/check-status` | Unified 6-stage health audit across environment | To check keyboard, DMI, power, IM, cedilla, and gestures |
| `./bin/kde-config init` | `/init` | Guided full initialization with language selection & backup | On first-time setup or to reconfigure all components |
| `./bin/kde-config fix-keyboard` | `/fix-keyboard` | Fixes `Ctrl+C` on ABNT2, native cedilla on US-intl, masks fcitx5 | When shortcuts fail or dead-key acute outputs `ć` instead of `ç` |
| `./bin/kde-config fix-tongfang` | `/fix-tongfang` | Unlocks matrix in GRUB for Tongfang/Avell laptops | If the physical notebook Control key does not respond |
| `./bin/kde-config smart-keyboard-power` | `/smart-keyboard-power` | Dynamic bus power (`on` standalone, `auto` with USB/BT keyboard) | To eliminate Left Ctrl latency/latch without battery waste |
| `./bin/kde-config battery-status` | `/battery` | Battery, hybrid GPU, and PCIe ASPM diagnostics (read-only) | To audit power consumption and battery health |
| `./bin/kde-config battery-apply` | `/battery` | Applies user-selected battery optimizations | To save power after inspecting diagnostics |
| `./bin/kde-config gestures` | `/configure-gestures` | Configures 3/4-finger touchpad gestures in KWin | To enable smooth workspace swipe and overview gestures |
| `./bin/kde-config mouse` | `/configure-mouse` | Configures Logitech MX Master 3S mouse via logiops | To map thumb gesture button and free-spin SmartShift |
| `./bin/kde-config test-keyboard` | `/test-keyboard` | Real-time key event monitor | To test whether any physical key is active |
| `./bin/kde-config monitor-irq` | `/monitor-irq` | Real-time hardware electric pulse monitor on IRQ 1 (i8042) | To test motherboard electric interrupts |
| `./bin/kde-config switch [br\|us]` | — | Switches active KWin layout via D-Bus | To switch layouts without relying on physical shortcuts |
| `./bin/kde-config report` | `/report` | Latest run report + historical trends & recommendations | To inspect execution history and solve warnings/failures |
| `./bin/kde-config upgrade` | `/upgrade` | Checks and applies updates from GitHub and marketplace | To upgrade the suite to the latest release |
| `./bin/kde-config rollback` | — | Restores previous configuration snapshot from backup | To revert changes made by the suite |

---

## Output Format (Mandatory across all tools)

Always report in these four phases, in this exact order:

### 1. Plan
Command to be executed and what it changes.

### 2. Execution
One line per step (`✅`, `⏭️`, `⚠️`, `❌`).

### 3. Summary
Table summarizing Changed, Language, Unchanged, Backup, and How to Revert.

### 4. Recommended Actions
Mandatory if any `⚠️` or `❌` occurs, providing the exact 1-line command to fix each issue.
