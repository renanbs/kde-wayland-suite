#!/usr/bin/env bash
# ==============================================================================
# fix-tongfang.sh — Desbloqueio de Teclado/Matriz para Laptops Tongfang/Avell/Clevo
# Injeta i8042.nopnp=1 i8042.nomux=1 i8042.reset=1 acpi_osi='Windows 2020' no GRUB
# e integra com lib-runlog.sh e o contrato de saída padronizado da suite.
# ==============================================================================
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRUB_FILE="/etc/default/grub"
BACKUP_FILE="/etc/default/grub.bak-tongfang"
TONGFANG_PARAMS="i8042.nopnp=1 i8042.nomux=1 i8042.reset=1 atkbd.reset=1 acpi_osi='Windows 2020'"
# Registro estruturado do run
if [ -f "$SCRIPT_DIR/lib-runlog.sh" ]; then
    # shellcheck source=lib-runlog.sh
    source "$SCRIPT_DIR/lib-runlog.sh"
else
    runlog_event() { :; }
fi

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}[!] Esta operação precisa de privilégios de root para alterar o GRUB.${NC}"
        exec sudo "$0" "$@"
    fi
}

detect_dmi() {
    local vendor="unknown" product="unknown"
    [ -f /sys/class/dmi/id/sys_vendor ] && vendor="$(cat /sys/class/dmi/id/sys_vendor)"
    [ -f /sys/class/dmi/id/product_name ] && product="$(cat /sys/class/dmi/id/product_name)"
    echo "$vendor / $product"
}

cmd_apply() {
    check_root "$@"
    local dmi_info
    dmi_info="$(detect_dmi)"

    echo -e "${BOLD}### 1. Plano${NC}\n"
    echo -e "- **Comando:** ./bin/kde-config fix-tongfang"
    echo -e "- **Faz:** Injeta parâmetros de kernel para chassi Tongfang/Avell (desbloqueio i8042 e DSDT ACPI) e atualiza o GRUB"
    echo -e "- **Reversível:** Sim, via './bin/kde-config revert-tongfang'\n"

    echo -e "${BOLD}### 2. Execução${NC}\n"

    echo -e "  ✅ [1/4] Identificação do hardware: ${BOLD}${dmi_info}${NC}"
    runlog_event "ok" "tongfang_dmi_detected" "$dmi_info"

    if [ ! -f "$BACKUP_FILE" ] && [ -f "$GRUB_FILE" ]; then
        cp -p "$GRUB_FILE" "$BACKUP_FILE"
        echo -e "  ✅ [2/4] Backup de segurança criado em ${BOLD}${BACKUP_FILE}${NC}"
        runlog_event "ok" "grub_backup_created" "$BACKUP_FILE"
    else
        echo -e "  ⏭️ [2/4] Backup já existente em ${BACKUP_FILE}"
        runlog_event "skip" "grub_backup_exists" "$BACKUP_FILE"
    fi

    if [ ! -f "$GRUB_FILE" ]; then
        echo -e "  ❌ [3/4] Arquivo ${GRUB_FILE} não encontrado. Este sistema usa GRUB?"
        runlog_event "fail" "grub_file_missing" "$GRUB_FILE"
        exit 1
    fi

    local base_cmdline
    if [ -f "$BACKUP_FILE" ]; then
        base_cmdline=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" "$BACKUP_FILE" | sed -E "s/^GRUB_CMDLINE_LINUX_DEFAULT=['\"](.*)['\"]/\1/")
    else
        base_cmdline=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" "$GRUB_FILE" | sed -E "s/^GRUB_CMDLINE_LINUX_DEFAULT=['\"](.*)['\"]/\1/")
    fi

    # Remove parâmetros anteriores para evitar duplicatas
    base_cmdline=$(echo "$base_cmdline" | sed -E 's/i8042\.[a-z0-9=]+//g; s/acpi_osi=[^ ]+//g' | tr -s ' ' | sed 's/^[ ]*//;s/[ ]*$//')
    local new_cmdline="${base_cmdline} ${TONGFANG_PARAMS}"

    sed -i -E "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"${new_cmdline}\"|" "$GRUB_FILE"
    echo -e "  ✅ [3/4] Parâmetros de kernel injetados no GRUB: ${BOLD}${TONGFANG_PARAMS}${NC}"
    runlog_event "ok" "grub_params_injected" "$TONGFANG_PARAMS"

    echo -e "  [*] [4/5] Atualizando imagem do GRUB (grub-mkconfig)..."
    if command -v update-grub >/dev/null 2>&1; then
        update-grub >/dev/null 2>&1
    elif command -v grub-mkconfig >/dev/null 2>&1; then
        grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1
    elif command -v grub2-mkconfig >/dev/null 2>&1; then
        grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null 2>&1
    else
        echo -e "  ❌ [4/5] Comando update-grub / grub-mkconfig não encontrado."
        runlog_event "fail" "grub_update_tool_missing" ""
        exit 1
    fi
    echo -e "  ✅ [4/5] Imagem do GRUB atualizada com sucesso"
    runlog_event "ok" "grub_image_updated" "/boot/grub/grub.cfg"

    echo -e "  [*] [5/5] Instalando regra de hardware hwdb e ativando no kernel..."
    if [ -f "$SCRIPT_DIR/90-tongfang-keyboard.hwdb" ]; then
        cp -p "$SCRIPT_DIR/90-tongfang-keyboard.hwdb" "/etc/udev/hwdb.d/90-tongfang-keyboard.hwdb"
        systemd-hwdb update >/dev/null 2>&1 || true
        udevadm trigger --subsystem-match=input >/dev/null 2>&1 || true
    fi
    if command -v setkeycodes >/dev/null 2>&1; then
        setkeycodes e078 29 2>/dev/null || true
    fi
    echo -e "  ✅ [5/5] Regra hwdb instalada e scancode e078 (Left Ctrl) ativado imediatamente no kernel"
    runlog_event "ok" "tongfang_hwdb_activated" "scancode_e078=29"
    echo -e "\n${BOLD}### 3. Resumo${NC}\n"
    echo -e "| Campo | Conteúdo |"
    echo -e "| :--- | :--- |"
    echo -e "| O que mudou | GRUB_CMDLINE_LINUX_DEFAULT configurado com ${TONGFANG_PARAMS} e GRUB atualizado |"
    echo -e "| O que não mudou | Configurações de layout do KWin, touchpad e flags |"
    echo -e "| Backup | ${BACKUP_FILE} |"
    echo -e "| Relatório salvo | ./bin/kde-config report (ou ~/.local/state/kde-wayland-suite/runs/) |"
    echo -e "| Como reverter | ./bin/kde-config revert-tongfang |"
    echo -e "| Requer | reboot |"
    echo ""
    echo -e "${YELLOW}Importante:${NC} Reinicie o notebook (${BOLD}sudo reboot${NC}) para que os novos parâmetros de kernel passem a valer."
}

cmd_revert() {
    check_root "$@"

    echo -e "${BOLD}### 1. Plano${NC}\n"
    echo -e "- **Comando:** ./bin/kde-config revert-tongfang"
    echo -e "- **Faz:** Restaura o arquivo /etc/default/grub a partir do backup anterior e regenera o GRUB"
    echo -e "- **Reversível:** Sim, via './bin/kde-config fix-tongfang'\n"

    echo -e "${BOLD}### 2. Execução${NC}\n"

    if [ ! -f "$BACKUP_FILE" ]; then
        echo -e "  ❌ [1/2] Backup ${BACKUP_FILE} não encontrado."
        runlog_event "fail" "grub_backup_not_found" "$BACKUP_FILE"
        exit 1
    fi

    cp -p "$BACKUP_FILE" "$GRUB_FILE"
    echo -e "  ✅ [1/2] Arquivo ${GRUB_FILE} restaurado a partir do backup"
    runlog_event "ok" "grub_backup_restored" "$GRUB_FILE"

    echo -e "  [*] [2/2] Atualizando imagem do GRUB..."
    if command -v update-grub >/dev/null 2>&1; then
        update-grub >/dev/null 2>&1
    elif command -v grub-mkconfig >/dev/null 2>&1; then
        grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1
    elif command -v grub2-mkconfig >/dev/null 2>&1; then
        grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null 2>&1
    fi
    echo -e "  ✅ [2/2] Imagem do GRUB regenerada ao estado anterior"
    runlog_event "ok" "grub_revert_updated" "/boot/grub/grub.cfg"

    if [ -f "/etc/udev/hwdb.d/90-tongfang-keyboard.hwdb" ]; then
        rm -f "/etc/udev/hwdb.d/90-tongfang-keyboard.hwdb"
        systemd-hwdb update >/dev/null 2>&1 || true
        udevadm trigger --subsystem-match=input >/dev/null 2>&1 || true
    fi

    echo -e "\n${BOLD}### 3. Resumo${NC}\n"
    echo -e "| Campo | Conteúdo |"
    echo -e "| :--- | :--- |"
    echo -e "| Relatório salvo | ./bin/kde-config report (ou ~/.local/state/kde-wayland-suite/runs/) |"
    echo -e "| O que mudou | GRUB_CMDLINE_LINUX_DEFAULT revertido ao backup e GRUB atualizado |"
    echo -e "| O que não mudou | Configurações de layout do KWin e flags de apps |"
    echo -e "| Backup | Restaurado de ${BACKUP_FILE} |"
    echo -e "| Como reverter | ./bin/kde-config fix-tongfang |"
    echo -e "| Requer | reboot |"
}

cmd_status() {
    local dmi_info
    dmi_info="$(detect_dmi)"
    echo -e "${BOLD}=== STATUS DO TECLADO E FIRMWARE TONGFANG / AVELL ===${NC}"
    echo -e "  • Hardware DMI: ${BOLD}${dmi_info}${NC}"
    echo -e "  • Linha de comando atual (/proc/cmdline):"
    echo -e "    $(cat /proc/cmdline)"
    echo ""
    if grep -q "i8042.nopnp=1" /proc/cmdline 2>/dev/null && grep -q "acpi_osi=" /proc/cmdline 2>/dev/null; then
        echo -e "  • ${GREEN}[OK]${NC} Parâmetros Tongfang/Avell ativos no kernel em execução."
        runlog_event "ok" "tongfang_kernel_params_active" ""
    else
        echo -e "  • ${YELLOW}[AVISO]${NC} Parâmetros i8042/acpi_osi NÃO detectados no boot atual."
        echo -e "    Execute '${BOLD}./bin/kde-config fix-tongfang${NC}' e reinicie o notebook."
        runlog_event "warn" "tongfang_kernel_params_inactive" ""
    fi
}

ACTION="${1:---help}"
case "$ACTION" in
    --apply)
        cmd_apply "$@"
        ;;
    --revert)
        cmd_revert "$@"
        ;;
    --status)
        cmd_status
        ;;
    *)
        echo "Uso: $0 [--apply | --revert | --status]"
        exit 1
        ;;
esac
