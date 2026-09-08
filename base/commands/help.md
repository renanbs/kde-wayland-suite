---
description: Displays the full reference manual of commands, shortcuts, solutions, and guided workflows for the Linux Wayland Suite.
---

# /help

Displays the quick reference help center for all commands available in the **Linux Wayland Suite**:

```bash
./bin/linux-wayland-config help
```

---

## Unified Command & Solutions Matrix

| CLI Command | Slash Command | Function / Action | When to Use |
| :--- | :--- | :--- | :--- |
| `./bin/linux-wayland-config init` | `/init` (or `/scan`) | Non-destructive hardware inspection & machine profiling | On first-time setup or to inspect all hardware safe & read-only |
| `./bin/linux-wayland-config setup` | `/setup` | Contextual modular configuration wizard based on detected hardware | To apply recommended settings for keyboards, Wi-Fi, gestures, etc. |
| `./bin/linux-wayland-config status` | `/check-status` | Unified 7-stage health audit across environment | To check keyboard, DMI, power, Wi-Fi, IM, cedilla, and gestures |
| `./bin/linux-wayland-config smart-wifi-power` | `/smart-wifi-power` | Dynamic Wi-Fi power (`off` on AC for zero latency, `on` on battery) | To prevent radio sleep/timeout for Orca, SSH and remote access |
| `./bin/linux-wayland-config screen-hz [60\|120]` | — | Switches internal display refresh rate (60 Hz vs 120 Hz) | To save 2W-3W on battery or restore high refresh rate |
| `./bin/linux-wayland-config fix-keyboard` | `/fix-keyboard` | Fixes `Ctrl+C` on ABNT2, native cedilla on US-intl, masks fcitx5 | When shortcuts fail or dead-key acute outputs `ć` instead of `ç` |
| `./bin/linux-wayland-config fix-tongfang` | `/fix-tongfang` | Unlocks matrix in GRUB for Tongfang/Avell laptops | If the physical notebook Control key does not respond |
| `./bin/linux-wayland-config smart-keyboard-power` | `/smart-keyboard-power` | Dynamic bus power (`on` standalone, `auto` with USB/BT keyboard) | To eliminate Left Ctrl latency/latch without battery waste |
| `./bin/linux-wayland-config battery-status` | `/battery` | Battery, hybrid GPU, and PCIe ASPM diagnostics (read-only) | To audit power consumption and battery health |
| `./bin/linux-wayland-config battery-apply` | `/battery` | Applies user-selected battery optimizations | To save power after inspecting diagnostics |
| `./bin/linux-wayland-config gestures` | `/configure-gestures` | Configures 3/4-finger touchpad gestures in KWin | To enable smooth workspace swipe and overview gestures |
| `./bin/linux-wayland-config mouse` | `/configure-mouse` | Configures Logitech MX Master 3S mouse via logiops | To map thumb gesture button and free-spin SmartShift |
| `./bin/linux-wayland-config test-keyboard` | `/test-keyboard` | Real-time key event monitor | To test whether any physical key is active |
| `./bin/linux-wayland-config monitor-irq` | `/monitor-irq` | Real-time hardware electric pulse monitor on IRQ 1 (i8042) | To test motherboard electric interrupts |
| `./bin/linux-wayland-config switch [br\|us]` | — | Switches active KWin layout via D-Bus | To switch layouts without relying on physical shortcuts |
| `./bin/linux-wayland-config report` | `/report` | Latest run report + historical trends & recommendations | To inspect execution history and solve warnings/failures |
| `./bin/linux-wayland-config upgrade` | `/upgrade` | Checks and applies updates from GitHub and marketplace | To upgrade the suite to the latest release |
| `./bin/linux-wayland-config rollback` | — | Restores previous configuration snapshot from backup | To revert changes made by the suite |

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
