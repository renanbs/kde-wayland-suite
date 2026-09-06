#!/usr/bin/env bash
# ==============================================================================
# manage-keyboard-power.sh — Gerenciamento Inteligente de Energia do Teclado
#
# Comportamento:
# - Sem teclado externo: define /sys/devices/platform/i8042/serio0/power/control = "on"
#   (evita suspensão do barramento PS/2, eliminando a trava/latência do Left Ctrl).
# - Com teclado externo (USB/Bluetooth): define power/control = "auto"
#   (coloca o teclado integrado em economia de energia enquanto você digita no externo).
#
# Suporta:
#   --sync         Executa a verificação e ajusta o power/control na hora
#   --apply-udev   Instala a regra udev para disparo automático em plug/unplug
#   --remove-udev  Remove a regra udev do sistema
#   --status       Exibe o estado atual do barramento e dispositivos conectados
# ==============================================================================
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERIO_POWER="/sys/devices/platform/i8042/serio0/power/control"
UDEV_RULE_FILE="/etc/udev/rules.d/90-kde-smart-keyboard-power.rules"

# Registro estruturado do run
if [ -f "$SCRIPT_DIR/lib-runlog.sh" ]; then
    # shellcheck source=lib-runlog.sh
    source "$SCRIPT_DIR/lib-runlog.sh"
else
    runlog_event() { :; }
    runlog_metric() { :; }
fi

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}[!] Esta operação requer privilégios de root (sudo).${NC}"
        exec sudo "$0" "$@"
    fi
}

count_external_keyboards() {
    local count=0
    for path in /sys/class/input/input*; do
        [ -d "$path" ] || continue
        local name_file="$path/name"
        [ -f "$name_file" ] || continue
        local name
        name="$(cat "$name_file" 2>/dev/null || echo '')"

        # Ignora botões ACPI, switches, placas de vídeo e áudio
        if echo "$name" | grep -qiE "Button|Switch|Virtual|ydotool|LogiOps|Video Bus|HDA|Mouse|Touchpad"; then
            continue
        fi

        # Ignora teclado integrado i8042
        if echo "$name" | grep -qi "AT Translated Set 2 keyboard"; then
            continue
        fi

        # Verifica se tem capacidade EV_KEY (bit 1 de capabilities/ev)
        local caps_file="$path/capabilities/ev"
        if [ -f "$caps_file" ]; then
            local ev_hex
            ev_hex="$(cat "$caps_file" 2>/dev/null || echo '0')"
            # Converte hex para decimal e testa bit 1 (0x02)
            local ev_dec=$((16#$ev_hex))
            if (( (ev_dec & 2) != 0 )); then
                count=$((count + 1))
            fi
        fi
    done
    echo "$count"
}

cmd_sync() {
    local ext_count
    ext_count="$(count_external_keyboards)"

    if [ ! -f "$SERIO_POWER" ]; then
        echo -e "${YELLOW}[AVISO]${NC} Arquivo $SERIO_POWER não encontrado. Este sistema não possui barramento i8042/serio0?"
        runlog_event "skip" "serio_power_missing" "$SERIO_POWER"
        return 0
    fi

    local current_val
    current_val="$(cat "$SERIO_POWER" 2>/dev/null || echo 'unknown')"

    if [ "$ext_count" -gt 0 ]; then
        # Teclado externo conectado -> economia de energia (auto)
        if [ "$current_val" != "auto" ]; then
            echo "auto" > "$SERIO_POWER" 2>/dev/null || check_root "$@"
            echo -e "  • ${GREEN}[OK]${NC} Teclado externo detectado ($ext_count conectado(s)). Barramento integrado alterado para: ${BOLD}auto${NC} (economia de energia)."
            runlog_event "ok" "keyboard_power_auto" "ext_keyboards=$ext_count"
        else
            echo -e "  • ${GREEN}[OK]${NC} Teclado externo detectado ($ext_count conectado(s)). Barramento integrado já está em: ${BOLD}auto${NC}."
            runlog_event "ok" "keyboard_power_already_auto" "ext_keyboards=$ext_count"
        fi
    else
        # Nenhum teclado externo -> alta responsividade sem travamento (on)
        if [ "$current_val" != "on" ]; then
            echo "on" > "$SERIO_POWER" 2>/dev/null || check_root "$@"
            echo -e "  • ${GREEN}[OK]${NC} Somente teclado integrado ativo. Barramento i8042 alterado para: ${BOLD}on${NC} (zero latência / anti-latch)."
            runlog_event "ok" "keyboard_power_on" "ext_keyboards=0"
        else
            echo -e "  • ${GREEN}[OK]${NC} Somente teclado integrado ativo. Barramento i8042 já está em: ${BOLD}on${NC}."
            runlog_event "ok" "keyboard_power_already_on" "ext_keyboards=0"
        fi
    fi
}

cmd_apply_udev() {
    check_root "$@"

    echo -e "${BOLD}### 1. Plano${NC}\n"
    echo -e "- **Comando:** ./bin/kde-config smart-keyboard-power --apply"
    echo -e "- **Faz:** Instala regra udev dinâmica em ${UDEV_RULE_FILE} para alternar power/control entre 'on' (notebook puro) e 'auto' (com teclado USB/Bluetooth)"
    echo -e "- **Reversível:** Sim, via './bin/kde-config smart-keyboard-power --remove'\n"

    echo -e "${BOLD}### 2. Execução${NC}\n"

    echo -e "  [*] [1/3] Gravando regra de hardware em ${BOLD}${UDEV_RULE_FILE}${NC}..."
    cat << EOF > "$UDEV_RULE_FILE"
# Regra Dinâmica de Energia do Teclado Integrado (KDE Wayland Suite)
# Alterna serio0 entre 'on' (sem teclado externo) e 'auto' (com teclado USB/Bluetooth)
ACTION=="add|remove", SUBSYSTEM=="input", ENV{ID_INPUT_KEYBOARD}=="1", RUN+="/bin/sh -c 'if [ -x \"$SCRIPT_DIR/manage-keyboard-power.sh\" ]; then \"$SCRIPT_DIR/manage-keyboard-power.sh\" --sync; fi'"
EOF
    echo -e "  ✅ [1/3] Regra udev gravada com sucesso"
    runlog_event "ok" "smart_keyboard_udev_created" "$UDEV_RULE_FILE"

    echo -e "  [*] [2/3] Recarregando regras do udev..."
    udevadm control --reload-rules
    echo -e "  ✅ [2/3] Regras do udev recarregadas"
    runlog_event "ok" "udev_rules_reloaded" ""

    echo -e "  [*] [3/3] Executando sincronização inicial de estado..."
    cmd_sync
    echo -e "  ✅ [3/3] Estado de energia sincronizado"

    echo -e "\n${BOLD}### 3. Resumo${NC}\n"
    echo -e "| Campo | Conteúdo |"
    echo -e "| :--- | :--- |"
    echo -e "| O que mudou | Regra udev ${UDEV_RULE_FILE} instalada e sincronização dinâmica ativada |"
    echo -e "| O que não mudou | Layouts de teclado e configurações do KWin |"
    echo -e "| Backup | Não aplicável (novo arquivo udev) |"
    echo -e "| Como reverter | ./bin/kde-config smart-keyboard-power --remove |"
    echo -e "| Requer | nada (entra em vigor imediatamente) |"
}

cmd_remove_udev() {
    check_root "$@"

    echo -e "${BOLD}### 1. Plano${NC}\n"
    echo -e "- **Comando:** ./bin/kde-config smart-keyboard-power --remove"
    echo -e "- **Faz:** Remove a regra udev dinâmica ${UDEV_RULE_FILE} e restaura power/control para 'auto'"
    echo -e "- **Reversível:** Sim, via './bin/kde-config smart-keyboard-power --apply'\n"

    echo -e "${BOLD}### 2. Execução${NC}\n"

    if [ -f "$UDEV_RULE_FILE" ]; then
        rm -f "$UDEV_RULE_FILE"
        echo -e "  ✅ [1/2] Arquivo ${UDEV_RULE_FILE} removido"
        runlog_event "ok" "smart_keyboard_udev_removed" "$UDEV_RULE_FILE"
    else
        echo -e "  ⏭️ [1/2] Arquivo ${UDEV_RULE_FILE} não existia"
        runlog_event "skip" "smart_keyboard_udev_not_found" ""
    fi

    udevadm control --reload-rules
    [ -f "$SERIO_POWER" ] && echo "auto" > "$SERIO_POWER" 2>/dev/null || true
    echo -e "  ✅ [2/2] Regras do udev recarregadas e barramento retornado a 'auto'"
    runlog_event "ok" "udev_rules_reloaded" ""

    echo -e "\n${BOLD}### 3. Resumo${NC}\n"
    echo -e "| Campo | Conteúdo |"
    echo -e "| :--- | :--- |"
    echo -e "| O que mudou | Regra udev removida e power/control restaurado ao padrão |"
    echo -e "| O que não mudou | Parâmetros do GRUB e atalhos |"
    echo -e "| Backup | nenhum |"
    echo -e "| Como reverter | ./bin/kde-config smart-keyboard-power --apply |"
    echo -e "| Requer | nada |"
}

cmd_status() {
    echo -e "${BOLD}=== STATUS DE ENERGIA DO TECLADO INTEGRADO ===${NC}"
    local ext_count
    ext_count="$(count_external_keyboards)"
    local current_val="unknown"
    [ -f "$SERIO_POWER" ] && current_val="$(cat "$SERIO_POWER" 2>/dev/null || echo 'unknown')"

    echo -e "  • Barramento i8042/serio0: ${BOLD}${SERIO_POWER}${NC}"
    echo -e "  • Modo de Energia Atual: ${BOLD}${current_val}${NC}"
    echo -e "  • Teclados Externos Conectados: ${BOLD}${ext_count}${NC}"

    if [ -f "$UDEV_RULE_FILE" ]; then
        echo -e "  • Regra Dinâmica udev: ${GREEN}[ATIVA]${NC} (${UDEV_RULE_FILE})"
    else
        echo -e "  • Regra Dinâmica udev: ${YELLOW}[INATIVA]${NC} (Execute './bin/kde-config smart-keyboard-power --apply')"
    fi
}

ACTION="${1:---status}"
case "$ACTION" in
    --sync)
        cmd_sync
        ;;
    --apply|--apply-udev)
        cmd_apply_udev "$@"
        ;;
    --remove|--remove-udev)
        cmd_remove_udev "$@"
        ;;
    --status)
        cmd_status
        ;;
    *)
        echo "Uso: $0 [--sync | --apply | --remove | --status]"
        exit 1
        ;;
esac
