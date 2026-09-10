#!/usr/bin/env python3
"""
manage-chromium-cedilla.py — Native Wayland Cedilla Fix (' + c -> ç) for Chromium & Electron
Part of linux-wayland-suite.

Applies the byte-pattern patch to ui::CharacterComposer in Chromium/Electron binaries,
resolving the hardcoded 'ć' bug on native Wayland without input methods.
Provides dynamic discovery, interactive selection, and Pacman hook management.
Bilingual support (en / pt-BR) via lib_suite.
"""

import os
import sys
import glob
import shutil
import subprocess
from datetime import datetime
from typing import List, Tuple, Dict, Optional

# Import shared suite library
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
from lib_suite import UI, I18n, get_active_language, render_table, render_banner, log_event

PYTHON_PATCHER = os.path.join(SCRIPT_DIR, "chromium-cedilla-patch.py")
PACMAN_HOOK_FILE = "/etc/pacman.d/hooks/99-cedilla-wayland.hook"
SYSTEM_WRAPPER = "/usr/local/bin/linux-wayland-patch-cedilla"

# ==============================================================================
# Internationalization Catalog (en / pt-BR)
# ==============================================================================

STRINGS = {
    "title_status": {
        "en": "Wayland Cedilla Audit (Chromium / Electron)",
        "pt-BR": "Auditoria da Cedilha Wayland (Chromium / Electron)",
    },
    "title_apply": {
        "en": "Wayland Cedilla Patch Application",
        "pt-BR": "Aplicação do Patch da Cedilha Wayland",
    },
    "title_revert": {
        "en": "Reverting Cedilla Patch on Binaries",
        "pt-BR": "Revertendo Patch da Cedilha nos Binários",
    },
    "author_credit": {
        "en": "Original patch engine by Leandro Cassa (lcassa/chromium-wayland-cedilla-fix)",
        "pt-BR": "Motor original por Leandro Cassa (lcassa/chromium-wayland-cedilla-fix)",
    },
    "col_app": {"en": "APPLICATION", "pt-BR": "APLICATIVO"},
    "col_size": {"en": "SIZE", "pt-BR": "TAMANHO"},
    "col_status": {"en": "PATCH STATUS", "pt-BR": "ESTADO DO PATCH"},
    "col_backup": {"en": "BACKUP .ORIG", "pt-BR": "BACKUP .ORIG"},
    "status_patched": {"en": "✔ PATCHED ('+c -> ç)", "pt-BR": "✔ CORRIGIDO ('+c -> ç)"},
    "status_vuln": {"en": "✖ VULNERABLE ('+c -> ć)", "pt-BR": "✖ VULNERÁVEL ('+c -> ć)"},
    "status_ineligible": {"en": "Ineligible", "pt-BR": "Não aplicável"},
    "backup_present": {"en": "Present", "pt-BR": "Presente"},
    "backup_missing": {"en": "Missing", "pt-BR": "Ausente"},
    "sec_binaries": {
        "en": "1. Detected Binaries and Cedilla State (' + c):",
        "pt-BR": "1. Binários Detectados e Estado da Cedilha (' + c):",
    },
    "sec_automation": {
        "en": "2. Automation & Autorepair on Upgrade (Pacman Hook):",
        "pt-BR": "2. Automação e Autocura pós-atualização (Pacman Hook):",
    },
    "hook_active": {
        "en": "Pacman Hook:     ✔ ACTIVE ({path})",
        "pt-BR": "Gancho do Pacman:   ✔ ATIVO ({path})",
    },
    "hook_missing": {
        "en": "Pacman Hook:     ⚠ NOT INSTALLED (package updates will overwrite patch)",
        "pt-BR": "Gancho do Pacman:   ⚠ NÃO INSTALADO (atualizações vão sobrescrever o patch)",
    },
    "wrapper_installed": {
        "en": "System Wrapper:  ✔ INSTALLED ({path})",
        "pt-BR": "Wrapper do Sistema: ✔ INSTALADO ({path})",
    },
    "wrapper_missing": {
        "en": "System Wrapper:  ⚠ NOT INSTALLED",
        "pt-BR": "Wrapper do Sistema: ⚠ NÃO INSTALADO",
    },
    "summary_vuln": {
        "en": "There are {count} application(s) needing correction.\nTo apply the patch and enable pacman autorepair:\n  {cmd} patch-cedilla --apply",
        "pt-BR": "Existem {count} aplicativo(s) necessitando de correção.\nPara aplicar o patch e ativar a autocura no pacman:\n  {cmd} patch-cedilla --apply",
    },
    "summary_clean": {
        "en": "✔ All detected applications have the cedilla patch applied.",
        "pt-BR": "✔ Todos os aplicativos detectados estão com a cedilha corrigida.",
    },
    "no_binaries": {
        "en": "⚠ No Chromium or Electron binaries detected.",
        "pt-BR": "⚠ Nenhum binário Chromium ou Electron foi detectado.",
    },
    "step1_detecting": {
        "en": "==> [1/3] Detecting installed Chromium and Electron binaries...",
        "pt-BR": "==> [1/3] Detectando binários Chromium e Electron instalados...",
    },
    "apps_found_list": {
        "en": "\nApplications detected on this system:\n",
        "pt-BR": "\nAplicativos encontrados no sistema:\n",
    },
    "choose_apps_prompt": {
        "en": "Choose which applications to patch:\n  • Enter numbers separated by space (e.g. 1 2 6)\n  • 'V' = Patch only vulnerable applications ({count} apps) [Recommended]\n  • 'A' = Patch all detected applications\n  • 'Q' = Quit without making changes",
        "pt-BR": "Escolha quais aplicativos deseja patchear:\n  • Digite os números separados por espaço (ex: 1 2 6)\n  • 'V' = Aplicar apenas nos que necessitam de patch ({count} apps) [Recomendado]\n  • 'A' = Aplicar em todos os detectados\n  • 'Q' = Cancelar sem modificar nada",
    },
    "prompt_choice": {
        "en": "Option [Default: V]: ",
        "pt-BR": "Opção [Padrão: V]: ",
    },
    "cancelled": {
        "en": "\nOperation cancelled by user.",
        "pt-BR": "\nOperação cancelada pelo usuário.",
    },
    "step2_patching": {
        "en": "\n==> [2/3] Applying byte patch on selected applications ({count})...",
        "pt-BR": "\n==> [2/3] Aplicando patch de bytes nos aplicativos selecionados ({count})...",
    },
    "processing": {
        "en": "  • Processing: {name} ({path})",
        "pt-BR": "  • Processando: {name} ({path})",
    },
    "sudo_needed": {
        "en": "    [SUDO] File requires root privileges for modification.",
        "pt-BR": "    [SUDO] O arquivo requer privilégios de root para modificação.",
    },
    "step3_hook": {
        "en": "\n==> [3/3] Autorepair on Package Upgrades via Pacman Hook",
        "pt-BR": "\n==> [3/3] Autocura pós-atualização via Pacman Hook",
    },
    "hook_explainer": {
        "en": "  💡 How the Pacman hook works:\n     When packages like Google Chrome, Orca IDE, or VS Code are updated via pacman/paru,\n     the package manager downloads factory versions that revert the cedilla patch.\n     The hook at /etc/pacman.d/hooks/99-cedilla-wayland.hook automatically reapplies the patch\n     only to updated packages, completely transparently.\n",
        "pt-BR": "  💡 Como funciona o gancho do Pacman:\n     Ao atualizar pacotes como Google Chrome, Orca IDE ou VS Code via pacman/paru,\n     o gerenciador sobrescreve os binários com versões de fábrica que desfazem o patch.\n     O gancho em /etc/pacman.d/hooks/99-cedilla-wayland.hook reaplica a correção\n     automaticamente pós-atualização, de forma totalmente transparente.\n",
    },
    "hook_prompt": {
        "en": "Do you want to install the Pacman hook to maintain autorepair on upgrades? [Y/n]: ",
        "pt-BR": "Deseja instalar o gancho do Pacman para manter a autocura nas atualizações? [S/n]: ",
    },
    "hook_skipped": {
        "en": "  ℹ Pacman hook skipped as requested.",
        "pt-BR": "  ℹ Gancho do Pacman ignorado conforme solicitado.",
    },
    "hook_installed_ok": {
        "en": "    ✔ Pacman hook and system wrapper installed successfully.",
        "pt-BR": "    ✔ Gancho do pacman e wrapper /usr/local/bin instalados com sucesso.",
    },
    "done_msg": {
        "en": "\n✔ Operation completed successfully!\nRestart modified applications for the cedilla (' + c -> ç) to take effect.\n",
        "pt-BR": "\n✔ Operação concluída com sucesso!\nReinicie os aplicativos modificados para que a cedilha (' + c -> ç) entre em vigor.\n",
    },
}

i18n = I18n(STRINGS)


# ==============================================================================
# Binary Discovery & Naming
# ==============================================================================

SEARCH_GLOBS = [
    "/opt/*/*",
    "/opt/*/*/*",
    "/usr/lib/electron*/electron",
    "/usr/lib/chromium/chromium",
    "/usr/share/code/code",
    "/usr/share/code-insiders/code-insiders",
    "/usr/share/vscodium*/codium*",
    os.path.expanduser("~/.config/discord/app-*/Discord"),
    "/usr/lib/discord/Discord",
    "/opt/discord/Discord",
]

def discover_binaries() -> List[str]:
    """Dynamically finds installed Chromium and Electron ELF executables (>25MB)."""
    found = set()
    for pattern in SEARCH_GLOBS:
        for p in glob.glob(pattern):
            if not os.path.isfile(p) or not os.access(p, os.X_OK):
                continue
            # Ignore backup copies
            if p.endswith(".orig") or ".bak-" in p or ".tmp-" in p or p.endswith(".bak"):
                continue
            try:
                rp = os.path.realpath(p)
                if os.path.getsize(rp) > 25 * 1024 * 1024:
                    with open(rp, "rb") as f:
                        if f.read(4) == b"\x7fELF":
                            found.add(rp)
            except (OSError, PermissionError):
                continue
    return sorted(list(found))

def app_display_name(path: str) -> str:
    """Returns clean human-readable name for a binary path."""
    p_lower = path.lower()
    if "chrome/chrome" in p_lower:
        return "Google Chrome"
    elif "chromium/chromium" in p_lower:
        return "Chromium"
    elif "brave" in p_lower:
        return "Brave Browser"
    elif "msedge" in p_lower:
        return "Microsoft Edge"
    elif "electron43/electron" in p_lower:
        return "Orca IDE (Electron 43)"
    elif "electron" in p_lower:
        for part in path.split("/"):
            if part.startswith("electron") and part[8:].isdigit():
                return f"Electron Runtime ({part})"
        return "Electron Runtime"
    elif "code/code" in p_lower or "code-insiders" in p_lower:
        return "Visual Studio Code"
    elif "vscodium" in p_lower:
        return "VSCodium"
    elif "discord" in p_lower:
        return "Discord"
    elif "antigravity-ide" in p_lower:
        return "Antigravity IDE"
    elif "antigravity" in p_lower:
        return "Antigravity Platform"
    return os.path.basename(path)

def check_binary_status(bin_path: str) -> Tuple[str, int]:
    """
    Returns (status, count) where status is 'PATCHED', 'VULNERABLE', or 'INELIGIBLE'.
    """
    if not os.path.isfile(bin_path):
        return ("NOT_FOUND", 0)
    try:
        with open(bin_path, "rb") as f:
            data = f.read()
        needs = data.count(b"\x63\x00\x07\x01")
        patched = data.count(b"\x63\x00\xe7\x00")
        if needs > 0:
            return ("VULNERABLE", needs)
        elif patched > 0:
            return ("PATCHED", patched)
        return ("INELIGIBLE", 0)
    except Exception:
        return ("ERROR", 0)


# ==============================================================================
# Command Actions: status, apply, revert
# ==============================================================================

def cmd_status() -> int:
    print(render_banner(i18n.t("title_status"), i18n.t("author_credit")))
    print(f"{UI.BOLD}{i18n.t('sec_binaries')}{UI.RESET}\n")

    binaries = discover_binaries()
    if not binaries:
        print(f"  {UI.WARNING}{i18n.t('no_binaries')}{UI.RESET}\n")
        return 0

    headers = [
        i18n.t("col_app"),
        i18n.t("col_size"),
        i18n.t("col_status"),
        i18n.t("col_backup"),
    ]

    rows = []
    total_vuln = 0
    total_patched = 0

    for b in binaries:
        name = app_display_name(b)
        size_mb = f"{os.path.getsize(b) / (1024*1024):.1f} MB"
        status, _ = check_binary_status(b)

        if status == "PATCHED":
            status_desc = f"{UI.SUCCESS}{i18n.t('status_patched')}{UI.RESET}"
            total_patched += 1
        elif status == "VULNERABLE":
            status_desc = f"{UI.DANGER}{i18n.t('status_vuln')}{UI.RESET}"
            total_vuln += 1
        else:
            status_desc = f"{UI.MUTED}{i18n.t('status_ineligible')}{UI.RESET}"

        has_orig = os.path.isfile(b + ".orig")
        backup_desc = f"{UI.SUCCESS}{i18n.t('backup_present')}{UI.RESET}" if has_orig else f"{UI.WARNING}{i18n.t('backup_missing')}{UI.RESET}"

        rows.append([f"{UI.BOLD}{name}{UI.RESET}", f"{UI.MUTED}{size_mb}{UI.RESET}", status_desc, backup_desc])

    print(render_table(headers, rows))

    print(f"\n{UI.BOLD}{i18n.t('sec_automation')}{UI.RESET}")
    if os.path.isfile(PACMAN_HOOK_FILE):
        print(f"  • {UI.SUCCESS}{i18n.t('hook_active', path=PACMAN_HOOK_FILE)}{UI.RESET}")
        log_event("ok", "cedilla_hook_active", PACMAN_HOOK_FILE)
    else:
        print(f"  • {UI.WARNING}{i18n.t('hook_missing')}{UI.RESET}")
        log_event("warn", "cedilla_hook_missing")

    if os.path.isfile(SYSTEM_WRAPPER) or os.path.islink(SYSTEM_WRAPPER):
        print(f"  • {UI.SUCCESS}{i18n.t('wrapper_installed', path=SYSTEM_WRAPPER)}{UI.RESET}")
    else:
        print(f"  • {UI.WARNING}{i18n.t('wrapper_missing')}{UI.RESET}")
    print("")
    if total_vuln > 0:
        cmd_name = "./bin/linux-wayland-config"
        print(f"{UI.WARNING}{i18n.t('summary_vuln', count=total_vuln, cmd=cmd_name)}{UI.RESET}\n")
        return 1
    else:
        print(f"{UI.SUCCESS}{i18n.t('summary_clean')}{UI.RESET}\n")
        return 0


def patch_binary(target: str) -> bool:
    """Invokes python patcher with root elevation if needed."""
    if not os.access(target, os.W_OK) and os.geteuid() != 0:
        print(f"    {UI.WARNING}{i18n.t('sudo_needed')}{UI.RESET}")
        cmd = ["sudo", "python3", PYTHON_PATCHER, target]
    else:
        cmd = ["python3", PYTHON_PATCHER, target]

    res = subprocess.run(cmd)
    return res.returncode == 0


def cmd_apply(args: List[str]) -> int:
    auto_all = any(a in ("--all", "-y", "--yes") for a in args)
    explicit_targets = [a for a in args if os.path.isfile(a)]

    print(render_banner(i18n.t("title_apply"), i18n.t("author_credit")))
    print(f"{UI.PRIMARY}{i18n.t('step1_detecting')}{UI.RESET}")

    if explicit_targets:
        discovered = explicit_targets
    elif not sys.stdin.isatty():
        # Reading from pipe (pacman hook with NeedsTargets)
        discovered = []
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            for cand in ("/" + line, line):
                if os.path.isfile(cand):
                    discovered.append(cand)
                    break
        auto_all = True
    else:
        discovered = discover_binaries()

    if not discovered:
        print(f"    {UI.WARNING}{i18n.t('no_binaries')}{UI.RESET}")
        return 0

    targets = []
    is_interactive = (not auto_all) and sys.stdin.isatty() and (len(explicit_targets) == 0)

    if is_interactive:
        print(i18n.t("apps_found_list"))
        vuln_indices = []
        for idx, b in enumerate(discovered, 1):
            name = app_display_name(b)
            status, _ = check_binary_status(b)
            if status == "PATCHED":
                badge = f"{UI.SUCCESS}[{i18n.t('status_patched')}]{UI.RESET}"
            elif status == "VULNERABLE":
                badge = f"{UI.DANGER}[{i18n.t('status_vuln')}]{UI.RESET}"
                vuln_indices.append(idx)
            else:
                badge = f"{UI.MUTED}[{i18n.t('status_ineligible')}]{UI.RESET}"

            print(f"  {UI.PRIMARY}{idx:2d}){UI.RESET} {UI.BOLD}{name:<26}{UI.RESET} {badge} {UI.MUTED}({b}){UI.RESET}")

        print("")
        print(i18n.t("choose_apps_prompt", count=len(vuln_indices)))
        print("")
        try:
            choice = input(f"{UI.BOLD}{i18n.t('prompt_choice')}{UI.RESET}").strip()
        except (KeyboardInterrupt, EOFError):
            print(f"\n{UI.WARNING}{i18n.t('cancelled')}{UI.RESET}")
            return 0

        choice = choice or "V"
        if choice.lower().startswith("q"):
            print(f"{UI.WARNING}{i18n.t('cancelled')}{UI.RESET}")
            return 0
        elif choice.lower() == "a":
            targets = discovered
        elif choice.lower() == "v":
            targets = [discovered[i - 1] for i in vuln_indices]
        else:
            for part in choice.split():
                if part.isdigit():
                    n = int(part)
                    if 1 <= n <= len(discovered):
                        targets.append(discovered[n - 1])
    else:
        targets = discovered

    if not targets:
        print(f"  {UI.MUTED}{i18n.t('cancelled')}{UI.RESET}")
        return 0

    print(f"{UI.PRIMARY}{i18n.t('step2_patching', count=len(targets))}{UI.RESET}")
    for target in targets:
        name = app_display_name(target)
        print(i18n.t("processing", name=f"{UI.BOLD}{name}{UI.RESET}", path=f"{UI.MUTED}{target}{UI.RESET}"))
        if patch_binary(target):
            log_event("ok", "cedilla_patched", target)
        else:
            log_event("fail", "cedilla_patch_failed", target)

    print(f"{UI.PRIMARY}{i18n.t('step3_hook')}{UI.RESET}")
    want_hook = True
    if is_interactive:
        print(i18n.t("hook_explainer"))
        try:
            h_ans = input(f"{UI.BOLD}{i18n.t('hook_prompt')}{UI.RESET}").strip()
        except (KeyboardInterrupt, EOFError):
            h_ans = "y"
        h_ans = h_ans or "y"
        if h_ans.lower().startswith("n"):
            want_hook = False
            print(i18n.t("hook_skipped"))

    if want_hook and os.path.isdir("/etc/pacman.d"):
        install_hook_script = f"""
mkdir -p /etc/pacman.d/hooks /usr/local/bin
cat << 'EOF' > {SYSTEM_WRAPPER}
#!/usr/bin/env bash
exec "{SCRIPT_DIR}/manage-chromium-cedilla.py" --apply --yes "$@"
EOF
chmod +x {SYSTEM_WRAPPER}

cat << 'EOF' > {PACMAN_HOOK_FILE}
[Trigger]
Operation = Install
Operation = Upgrade
Type = Path
Target = opt/*/*
Target = opt/*/*/*
Target = usr/lib/electron*/electron
Target = usr/lib/chromium/chromium
Target = usr/share/code/code
Target = usr/share/code-insiders/code-insiders
Target = usr/share/vscodium*/codium*

[Action]
Description = [linux-wayland-suite] Autocura da cedilha Wayland em apps Chromium/Electron...
When = PostTransaction
Exec = /usr/local/bin/linux-wayland-patch-cedilla
NeedsTargets
EOF
"""
        if os.geteuid() != 0:
            print(f"  • Installing pacman hook to {PACMAN_HOOK_FILE} via sudo...")
            subprocess.run(["sudo", "bash", "-c", install_hook_script])
        else:
            subprocess.run(["bash", "-c", install_hook_script])

        print(i18n.t("hook_installed_ok"))
        log_event("ok", "cedilla_hook_installed", PACMAN_HOOK_FILE)

    print(f"{UI.BOLD}{UI.SUCCESS}{i18n.t('done_msg')}{UI.RESET}")
    return 0


def cmd_revert() -> int:
    print(render_banner(i18n.t("title_revert")))
    binaries = discover_binaries()
    reverted_count = 0

    for b in binaries:
        orig = b + ".orig"
        if os.path.isfile(orig):
            name = app_display_name(b)
            print(f"  • Restoring: {UI.BOLD}{name}{UI.RESET} ({b})")
            restore_cmd = f"cp -p '{orig}' '{b}' && rm -f '{orig}' '{b}'.bak-*"
            if not os.access(b, os.W_OK) and os.geteuid() != 0:
                subprocess.run(["sudo", "bash", "-c", restore_cmd])
            else:
                subprocess.run(["bash", "-c", restore_cmd])
            reverted_count += 1
            log_event("ok", "cedilla_reverted", b)

    if os.path.isfile(PACMAN_HOOK_FILE):
        print(f"\n  • Removing pacman hook ({PACMAN_HOOK_FILE})...")
        rm_cmd = f"rm -f '{PACMAN_HOOK_FILE}' '{SYSTEM_WRAPPER}'"
        if os.geteuid() != 0:
            subprocess.run(["sudo", "bash", "-c", rm_cmd])
        else:
            subprocess.run(["bash", "-c", rm_cmd])
        log_event("ok", "cedilla_hook_removed")

    print(f"\n{UI.SUCCESS}✔ Reversion completed ({reverted_count} binaries restored).{UI.RESET}\n")
    return 0


def main():
    action = "status"
    remaining = []
    if len(sys.argv) > 1:
        first = sys.argv[1]
        if first in ("--apply", "-a", "apply"):
            action = "apply"
            remaining = sys.argv[2:]
        elif first in ("--revert", "-r", "revert"):
            action = "revert"
            remaining = sys.argv[2:]
        elif first in ("--discover", "discover"):
            action = "discover"
        elif first in ("--status", "-s", "status"):
            action = "status"
        elif first in ("--help", "-h", "help"):
            action = "help"
        else:
            action = "status"

    if action == "discover":
        for b in discover_binaries():
            print(b)
        return 0
    elif action == "status":
        return cmd_status()
    elif action == "apply":
        return cmd_apply(remaining)
    elif action == "revert":
        return cmd_revert()
    elif action == "help":
        print(f"Usage: {sys.argv[0]} [--status | --apply | --revert | --discover]")
        return 0


if __name__ == "__main__":
    sys.exit(main() or 0)
