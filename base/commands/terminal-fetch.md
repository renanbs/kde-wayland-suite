---
description: Manages terminal visual identity (Fastfetch), allowing dynamic switching between Dr460nized Neon Eagle, Mokka Mascot Cat, Hexagonal Emblem, and classic ASCII Dragon with automatic detection and rollback.
---

# /terminal-fetch

Manages the visual identity and logo displayed by **Fastfetch** when opening new terminal tabs in Konsole and other Wayland terminals:
- **Dr460nized Neon Eagle:** High-resolution low-poly geometric eagle head in neon violet/magenta/indigo via Kitty graphics protocol (`garuda-purple.png`).
- **Mokka Mascot Cat:** Pastel cat emblem from the Garuda Mokka / Catppuccin edition (`mokka-fastfetch.png`).
- **Modern Hexagonal Emblem:** Geometric "G" logo in magenta and royal blue (`garudalinux-logo.png`).
- **Classic ASCII Dragon:** Built-in fastfetch text art for Garuda Linux (`GarudaDragon`).
- **Reversion & Safety:** Atomic configuration backup (`~/.config/fastfetch/config.jsonc.bak`) and clean rollback to system defaults without touching `/usr/share/`.

```bash
./bin/linux-wayland-config terminal-fetch --menu
```

---

## Guided Configuration Flow (Mandatory for AI Agents)

Before applying changes, the agent **must use `AskUserQuestion` (or `ask`)** to collect user preference:

### Question 1 — Terminal Visual Identity (singleSelect):
- **"Dr460nized Neon Eagle (PNG / Kitty) (Recommended)"** — High-res low-poly geometric eagle head in neon violet/magenta/indigo (`garuda-purple.png`).
- **"Mokka Mascot Cat (PNG / Kitty)"** — Original Garuda Mokka mascot cat in pastel palette (`mokka-fastfetch.png`).
- **"Modern Hexagonal Emblem 'G' (PNG / Kitty)"** — Geometric Garuda monogram logo (`garudalinux-logo.png`).
- **"Classic Dr460nized ASCII Dragon"** — Native fastfetch ANSI text art dragon (`GarudaDragon`).
- **"Classic Garuda ASCII"** — Native fastfetch ANSI text art bird (`Garuda`).
- **"Revert to Distribution Default"** — Restores original system default preset and shell hooks.

### Mapping Answers to Command Execution:

* **Dr460nized Neon Eagle:**
  ```bash
  ./bin/linux-wayland-config terminal-fetch --apply --logo eagle
  ```
* **Mokka Mascot Cat:**
  ```bash
  ./bin/linux-wayland-config terminal-fetch --apply --logo cat
  ```
* **Modern Hexagonal Emblem:**
  ```bash
  ./bin/linux-wayland-config terminal-fetch --apply --logo emblem
  ```
* **Classic Dr460nized ASCII Dragon:**
  ```bash
  ./bin/linux-wayland-config terminal-fetch --apply --logo dragon-ascii
  ```
* **Classic Garuda ASCII:**
  ```bash
  ./bin/linux-wayland-config terminal-fetch --apply --logo garuda-ascii
  ```
* **Revert / Restore:**
  ```bash
  ./bin/linux-wayland-config terminal-fetch --revert
  ```
* **Query Current State:**
  ```bash
  ./bin/linux-wayland-config terminal-fetch --status
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
* **❌ Failure / Incompatibility:**
  - `<Component Name>`: **NOT APPLIED**.
    - **Raw Driver / Command Error:** `<exact error output or exit reason>`
    - **Technical Root Cause:** `<explanation of missing image asset or unsupported distro>`
    - **System Impact:** `<confirm system safely remained in prior valid state>`
* **🔒 Manual Permission Required:**
  - *(Note: terminal-fetch runs entirely in user space and does not require sudo).*

---

#### 🔬 Technical Evidence & Ground Truth:
| Component | Verified State | Observable Proof / Command | How to Revert |
| :--- | :--- | :--- | :--- |
| `Fastfetch Config` | `<Active Logo>` | `cat ~/.config/fastfetch/config.jsonc \| grep source` | `./bin/linux-wayland-config terminal-fetch --revert` |
| `Fish Shell Hook` | `<Active / Clean>` | `grep -q __garuda_fastfetch ~/.config/fish/config.fish` | `./bin/linux-wayland-config terminal-fetch --revert` |

---

#### 💡 Daily Impact & Practical Benefits:
* **Terminal Identity:** High-resolution branding rendered on every new Konsole tab with immediate visual responsiveness.
* **Safe User-Space Isolation:** Survives system updates without modifying root-owned `/usr/share/` files.

---

#### 👉 Action Required:
```bash
fastfetch
```
*(Open a new terminal tab or run `fastfetch` to see your new logo).*
