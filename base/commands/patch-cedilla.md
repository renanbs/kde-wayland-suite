---
description: Fixes native Wayland cedilla (' + c -> ç) in Chromium and Electron apps (Google Chrome, Orca IDE, VS Code, Discord, Brave, Antigravity) via a byte-pattern patch and installs a Pacman hook for automatic re-patching after upgrades.
---

# /patch-cedilla

Applies the binary byte-pattern patch to Chromium and Electron applications so that typing `' + c` produces `ç` (and `' + C` produces `Ç`) in native Wayland (`--ozone-platform=wayland`), bypassing the hardcoded `ui::CharacterComposer` bug:

```bash
./bin/kde-config patch-cedilla --apply
```

To inspect the current status and check which installed applications are patched or vulnerable without modifying anything:

```bash
./bin/kde-config patch-cedilla --status
```

To revert all patched binaries back to their pristine `.orig` backups and remove the Pacman hook:

```bash
./bin/kde-config patch-cedilla --revert
```

---

## What It Does

1. **Dynamic App Discovery:** Automatically detects all installed Chromium and Electron applications on the system (Google Chrome, Orca IDE / Electron 43, VS Code, Discord, Brave, Antigravity, and system Electron versions).
2. **Byte-Pattern Patching:** Replaces the hardcoded mapping in `ui::CharacterComposer`:
   * Lowercase: `63 00 07 01` (`c -> ć`) $\to$ `63 00 e7 00` (`c -> ç`)
   * Uppercase: `43 00 06 01` (`C -> Ć`) $\to$ `43 00 c7 00` (`C -> Ç`)
3. **Pristine Backups:** Keeps an unmolested `.orig` copy of each binary before writing.
4. **Pacman Autorepair Hook:** Installs `/etc/pacman.d/hooks/99-cedilla-wayland.hook` and `/usr/local/bin/linux-wayland-patch-cedilla`. Every time `pacman` or `paru` updates Chrome, Electron, or related packages, the patch is reapplied automatically post-transaction.


---

## Guided Interactive Flow (Mandatory for AI Agents)

When interacting with the user regarding cedilla issues in Chromium or Electron apps, the AI agent **must explicitly explain the origin of the fix and credit the author**:
1. **Attribution:** Inform the user that the core byte-pattern patcher is powered by the upstream solution created by **Leandro Cassa** ([lcassa/chromium-wayland-cedilla-fix](https://github.com/lcassa/chromium-wayland-cedilla-fix)).
2. **Technical Explanation:** Explain that the tool performs a direct, reversible byte-pattern replacement on the hardcoded `ui::CharacterComposer` table (`63 00 07 01` $\to$ `63 00 e7 00`) inside ELF binaries, allowing `' + c` to deliver `ç` under native Wayland without breaking Ctrl shortcuts.
3. **User Prompting:** When offering the patch, prompt the user with `AskUserQuestion` (or `ask`):
   * **"Apply Chromium & Electron Cedilla Patch"** — Runs `./bin/linux-wayland-config patch-cedilla --apply` (modifies binaries, installs Pacman hook).
   * **"Inspect Only (Read-Only Status)"** — Runs `./bin/linux-wayland-config patch-cedilla --status` to list vulnerable vs patched applications.
   * **"Revert to Original Factory Binaries"** — Runs `./bin/linux-wayland-config patch-cedilla --revert` to restore `.orig` pristine copies.
---

## Standard Output Format (Evidence-First Verdict)

Every command response must follow this structured, evidence-based format:

### 🎯 Verdict: [ ✅ SUCCESS | ❌ FAILURE | ⚠️ PARTIAL SUCCESS ]
*One clear sentence summarizing the real, observable outcome of the operation.*

---

#### 📋 Execution Breakdown:
* **✅ Applied Successfully:**
  - `<App Name>` (`<Path>`): Byte pattern replaced (`c -> ç`, `C -> Ç`), backup `.orig` saved.
  - `Pacman Hook`: `/etc/pacman.d/hooks/99-cedilla-wayland.hook` registered.
* **❌ Failure / Hardware Rejection:**
  - `<Component Name>`: **NOT APPLIED**.
    - **Raw Error:** `<exact error output or exit reason>`
    - **Technical Root Cause:** `<explanation>`
* **🔒 Manual Permission Required (Root):**
  - Explanation if elevation could not run in the non-interactive subshell.

---

#### 🔬 Technical Evidence & Ground Truth:
| Component | Verified State | Observable Proof / Command | How to Revert |
| :--- | :--- | :--- | :--- |
| Google Chrome | `PATCHED ('+c -> ç)` | `manage-chromium-cedilla.sh --status` | `./bin/kde-config patch-cedilla --revert` |
| Orca IDE (Electron 43) | `PATCHED ('+c -> ç)` | `manage-chromium-cedilla.sh --status` | `./bin/kde-config patch-cedilla --revert` |
| Pacman Hook | `ACTIVE` | `cat /etc/pacman.d/hooks/99-cedilla-wayland.hook` | `./bin/kde-config patch-cedilla --revert` |

---

#### 💡 Daily Impact & Practical Benefits:
* You can type `'` followed by `c` on your US / MX Keys keyboard and get `ç` immediately in Google Chrome, Orca IDE, VS Code, and Discord under native Wayland, with zero modifier gymnastics or broken `Ctrl+C` shortcuts.

---

#### 👉 Action Required (Mandatory if manual action, ⚠️ or ❌ occurs):
```bash
linux-wayland-config patch-cedilla --apply
```

---

## 👏 Upstream Attribution & Credits
The core byte-pattern patcher engine (`chromium-cedilla-patch.py`) was created by **Leandro Cassa**:
* **Upstream Repository:** [lcassa/chromium-wayland-cedilla-fix](https://github.com/lcassa/chromium-wayland-cedilla-fix)
* **AUR Package:** [chromium-cedilla-patch](https://aur.archlinux.org/packages/chromium-cedilla-patch)
* **License:** MIT
*(Execution note: run directly in your terminal without typing sudo; elevation is requested internally).*
