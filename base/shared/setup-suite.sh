#!/usr/bin/env bash
# ==============================================================================
# setup-suite.sh — Assistente de Configuração Modular Contextual
#
# Comportamento:
# - Lê ~/.config/linux-wayland-suite/machine-profile.json (executa profile se ausente).
# - Apresenta e aplica exclusivamente as otimizações relevantes para o hardware:
#   * --keyboard          Corrige layouts ABNT2/US-intl e cedilha nativa
#   * --autoheal          Instala proteção contra colapso de layout no login
#   * --wifi-power        Gerenciamento dinâmico de Wi-Fi (AC vs Bateria)
#   * --keyboard-power    Prevenção de suspensão da porta PS/2 do teclado
#   * --gestures          Gestos de touchpad Wayland (3/4 dedos)
#   * --mouse             Configuração para mouse Logitech MX Master 3S
#   * --screen-60         Define tela interna para modo econômico 60 Hz
#   * --screen-high       Restaura alta taxa de atualização da tela
#   * --tongfang          Desbloqueio de matriz de teclado Tongfang/Avell no GRUB
#   * --all               Aplica todas as otimizações recomendadas detectadas
# ==============================================================================
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE_FILE="${HOME}/.config/linux-wayland-suite/machine-profile.json"

# Registro estruturado do run
if [ -f "$SCRIPT_DIR/lib-runlog.sh" ]; then
    # shellcheck source=lib-runlog.sh
    source "$SCRIPT_DIR/lib-runlog.sh"
else
    runlog_event() { :; }
    runlog_metric() { :; }
fi

if [ -f "$SCRIPT_DIR/lib-battery-gpu.sh" ]; then
    # shellcheck source=lib-battery-gpu.sh
    source "$SCRIPT_DIR/lib-battery-gpu.sh"
fi

ensure_profile() {
    if [ ! -f "$PROFILE_FILE" ]; then
        echo -e "${BLUE}[INFO] Perfil da máquina não encontrado. Executando varredura inicial...${NC}\n"
        bash "$SCRIPT_DIR/profile-machine.sh"
        echo ""
    fi
}

read_profile_value() {
    local key_path="$1"
    python3 -c "
import json, os, sys
try:
    with open(os.path.expanduser('$PROFILE_FILE'), 'r') as f:
        data = json.load(f)
    keys = '$key_path'.split('.')
    val = data
    for k in keys:
        val = val[k]
    if isinstance(val, bool):
        print('true' if val else 'false')
    elif val is None:
        print('')
    else:
        print(val)
except Exception:
    print('')
" 2>/dev/null || echo ""
}

apply_keyboard() {
    echo -e "${BOLD}==> [Configuração] Layout de Teclado e Cedilha Nativa${NC}"
    bash "$SCRIPT_DIR/fix-keyboard.sh"
    runlog_event "ok" "setup_keyboard_applied" ""
}

apply_autoheal() {
    echo -e "${BOLD}==> [Configuração] Proteção de Auto-Cura de Layout no Login${NC}"
    KDE_SUITE_LAYOUT_AUTOHEAL=1 bash "$SCRIPT_DIR/fix-keyboard.sh"
    runlog_event "ok" "setup_autoheal_applied" ""
}

apply_wifi_power() {
    echo -e "${BOLD}==> [Configuração] Smart Wi-Fi Power (AC vs Bateria)${NC}"
    bash "$SCRIPT_DIR/manage-wifi-power.sh" --apply
    runlog_event "ok" "setup_wifi_power_applied" ""
}

apply_keyboard_power() {
    echo -e "${BOLD}==> [Configuração] Smart Keyboard Power (Barramento i8042)${NC}"
    bash "$SCRIPT_DIR/manage-keyboard-power.sh" --apply
    runlog_event "ok" "setup_keyboard_power_applied" ""
}

apply_gestures() {
    echo -e "${BOLD}==> [Configuração] Gestos de Touchpad (libinput-gestures)${NC}"
    bash "$SCRIPT_DIR/configure-gestures.sh"
    runlog_event "ok" "setup_gestures_applied" ""
}

apply_mouse() {
    echo -e "${BOLD}==> [Configuração] Logitech MX Master 3S (logiops)${NC}"
    bash "$SCRIPT_DIR/configure-mouse.sh"
    runlog_event "ok" "setup_mouse_applied" ""
}

apply_screen_60() {
    echo -e "${BOLD}==> [Configuração] Taxa de Atualização da Tela Interna (60 Hz)${NC}"
    read -r EDP_OUT EDP_CUR EDP_CUR_ID EDP_60_ID EDP_HIGH_ID <<< "$(find_edp_refresh_modes || true)"
    if [ -n "$EDP_OUT" ] && [ -n "$EDP_60_ID" ] && [ "$EDP_60_ID" != "none" ]; then
        if set_edp_mode "$EDP_OUT" "$EDP_60_ID"; then
            echo -e "  ✅ [OK] Tela $EDP_OUT alterada com sucesso para 60 Hz (modo $EDP_60_ID)."
            runlog_event "ok" "setup_screen_60_applied" "output=$EDP_OUT mode=$EDP_60_ID"
        else
            echo -e "  ❌ ${RED}[FALHA] O driver gráfico (i915/KMS) rejeitou o modo 60 Hz para a tela $EDP_OUT.${NC}"
            echo -e "     ${BOLD}Motivo:${NC} O painel interno possui taxa nativa fixa em ${EDP_CUR} Hz e o driver não suporta alternância para 60 Hz."
            echo -e "     ${BOLD}Resultado:${NC} A taxa de 60 Hz ${RED}NÃO FOI APLICADA${NC}. A tela permanece em ${BOLD}${EDP_CUR} Hz${NC}."
            runlog_event "fail" "setup_screen_60_rejected" "driver rejected mode $EDP_60_ID on $EDP_OUT"

            # Registra no machine-profile.json para que esta opção inválida não seja mais exibida
            python3 -c "
import json, os
p_file = os.path.expanduser('$PROFILE_FILE')
if os.path.exists(p_file):
    try:
        with open(p_file, 'r') as f:
            d = json.load(f)
        d.setdefault('display', {})['mode_60_available'] = False
        d['display']['mode_60_rejected'] = True
        d['display']['hardware_fixed_hz'] = int('${EDP_CUR:-120}') if '${EDP_CUR:-120}'.isdigit() else 120
        with open(p_file, 'w') as f:
            json.dump(d, f, indent=2)
    except Exception:
        pass
" 2>/dev/null || true
        fi
    else
        echo -e "  ⏭️ [INFO] Modo 60 Hz não disponível para a tela interna."
        runlog_event "skip" "setup_screen_60_unavailable" ""
    fi
}

apply_screen_high() {
    echo -e "${BOLD}==> [Configuração] Taxa de Atualização da Tela Interna (Alta Taxa)${NC}"
    read -r EDP_OUT EDP_CUR EDP_CUR_ID EDP_60_ID EDP_HIGH_ID <<< "$(find_edp_refresh_modes || true)"
    if [ -n "$EDP_OUT" ] && [ -n "$EDP_HIGH_ID" ] && [ "$EDP_HIGH_ID" != "none" ]; then
        if set_edp_mode "$EDP_OUT" "$EDP_HIGH_ID"; then
            echo -e "${GREEN}✔ Tela $EDP_OUT alterada para alta taxa (modo $EDP_HIGH_ID).${NC}"
            runlog_event "ok" "setup_screen_high_applied" "output=$EDP_OUT mode=$EDP_HIGH_ID"
        else
            echo -e "${YELLOW}⚠️ O driver gráfico rejeitou a alteração para alta taxa.${NC}"
            runlog_event "warn" "setup_screen_high_rejected" "driver rejected mode $EDP_HIGH_ID"
        fi
    else
        echo -e "${YELLOW}[INFO] Modo de alta taxa não disponível para a tela interna.${NC}"
        runlog_event "skip" "setup_screen_high_unavailable" ""
    fi
}

apply_tongfang() {
    echo -e "${BOLD}==> [Configuração] Desbloqueio de Matriz Tongfang/Avell no GRUB${NC}"
    bash "$SCRIPT_DIR/fix-tongfang.sh" --apply
    runlog_event "ok" "setup_tongfang_applied" ""
}

apply_all_detected() {
    echo -e "${BOLD}### 1. Plano${NC}\n"
    echo -e "- **Comando:** ./bin/linux-wayland-config setup --all"
    echo -e "- **Faz:** Aplica as configurações recomendadas com base no hardware detectado em ${PROFILE_FILE}"
    echo -e "- **Reversível:** Sim, através dos comandos individuais de reversão\n"

    echo -e "${BOLD}### 2. Execução${NC}\n"

    apply_keyboard
    echo ""

    local has_autoheal
    has_autoheal="$(read_profile_value "input.layout_autoheal_installed")"
    if [ "$has_autoheal" != "true" ]; then
        apply_autoheal
        echo ""
    fi

    local has_i8042
    has_i8042="$(read_profile_value "input.i8042_present")"
    if [ "$has_i8042" = "true" ]; then
        apply_keyboard_power
        echo ""
    fi

    local is_tongfang tongfang_unlocked
    is_tongfang="$(read_profile_value "input.is_tongfang_candidate")"
    tongfang_unlocked="$(read_profile_value "input.tongfang_grub_unlocked")"
    if [ "$is_tongfang" = "true" ] && [ "$tongfang_unlocked" != "true" ]; then
        apply_tongfang
        echo ""
    fi

    local has_wifi
    has_wifi="$(python3 -c "
import json, os
with open(os.path.expanduser('$PROFILE_FILE')) as f:
    d = json.load(f)
print('true' if len(d.get('wifi', {}).get('interfaces', [])) > 0 else 'false')
" 2>/dev/null || echo "false")"
    if [ "$has_wifi" = "true" ]; then
        apply_wifi_power
        echo ""
    fi

    local has_touchpad
    has_touchpad="$(read_profile_value "input.touchpad_present")"
    if [ "$has_touchpad" = "true" ]; then
        apply_gestures
        echo ""
    fi

    local has_mouse
    has_mouse="$(read_profile_value "input.mx_master_present")"
    if [ "$has_mouse" = "true" ]; then
        apply_mouse
        echo ""
    fi

    echo -e "${BOLD}### 3. Resumo${NC}\n"
    echo -e "| Campo | Conteúdo |"
    echo -e "| :--- | :--- |"
    echo -e "| O que mudou | Configurações recomendadas aplicadas com sucesso |"
    echo -e "| O que não mudou | Arquivos pessoais e preferências não selecionadas |"
    echo -e "| Backup | Criado automaticamente para cada componente modificado |"
    echo -e "| Relatório salvo | ./bin/linux-wayland-config report |"
    echo -e "| Como reverter | ./bin/linux-wayland-config <componente> --remove / --revert |"
    echo -e "| Requer | Reiniciar a sessão (logout/login) para ativação total de layouts |"
}

show_interactive_menu() {
    echo -e "${BOLD}${BLUE}======================================================${NC}"
    echo -e "${BOLD}${BLUE}   Linux Wayland Suite — Assistente de Configuração   ${NC}"
    echo -e "${BOLD}${BLUE}======================================================${NC}\n"

    echo -e "${BOLD}Perfil detectado para esta máquina:${NC}"
    local vendor product distro desktop
    vendor="$(read_profile_value "dmi.vendor")"
    product="$(read_profile_value "dmi.product")"
    distro="$(read_profile_value "system.distro_name")"
    desktop="$(read_profile_value "system.desktop")"
    echo -e "  • Máquina: ${BOLD}${vendor} ${product}${NC}"
    echo -e "  • Sistema: ${BOLD}${distro}${NC} (${desktop})\n"

    echo -e "${BOLD}Otimizações disponíveis para o seu hardware:${NC}"
    echo -e "  1) ${GREEN}Teclado e Cedilha${NC}      (ABNT2 / US-intl ç nativo sem input method)"
    echo -e "  2) ${GREEN}Auto-Cura de Layout${NC}    (Proteção contra bug de colapso do KWin no reboot)"

    local has_i8042
    has_i8042="$(read_profile_value "input.i8042_present")"
    [ "$has_i8042" = "true" ] && echo -e "  3) ${GREEN}Smart Keyboard Power${NC}   (Anti-latch/latência no barramento i8042)"

    local has_wifi
    has_wifi="$(python3 -c "
import json, os
with open(os.path.expanduser('$PROFILE_FILE')) as f:
    d = json.load(f)
print('true' if len(d.get('wifi', {}).get('interfaces', [])) > 0 else 'false')
" 2>/dev/null || echo "false")"
    [ "$has_wifi" = "true" ] && echo -e "  4) ${GREEN}Smart Wi-Fi Power${NC}      (Power save OFF na tomada / ON na bateria)"

    local has_touchpad
    has_touchpad="$(read_profile_value "input.touchpad_present")"
    [ "$has_touchpad" = "true" ] && echo -e "  5) ${GREEN}Gestos de Touchpad${NC}     (3/4 dedos no Wayland via libinput-gestures)"

    local has_mouse
    has_mouse="$(read_profile_value "input.mx_master_present")"
    [ "$has_mouse" = "true" ] && echo -e "  6) ${GREEN}Logitech MX Master 3S${NC}  (Botões e SmartShift via logiops)"

    local mode_60 mode_60_rej
    mode_60="$(read_profile_value "display.mode_60_available")"
    mode_60_rej="$(read_profile_value "display.mode_60_rejected")"
    [ "$mode_60" = "true" ] && [ "$mode_60_rej" != "true" ] && echo -e "  7) ${GREEN}Tela 60 Hz Power-Saver${NC} (Economia de 2W-3W na tela interna)"

    local is_tongfang
    is_tongfang="$(read_profile_value "input.is_tongfang_candidate")"
    [ "$is_tongfang" = "true" ] && echo -e "  8) ${GREEN}Desbloqueio Tongfang${NC}   (Parâmetro i8042 no GRUB para teclado)"

    echo -e "  A) ${CYAN}Aplicar Todas Recomendadas${NC} (--all)"
    echo -e "  Q) Sair sem alterar nada\n"

    echo -e "Use as flags diretas para aplicar em lote ou scripts de automação:"
    echo -e "  ${BOLD}./bin/linux-wayland-config setup --all${NC}"
    echo -e "  ${BOLD}./bin/linux-wayland-config setup --keyboard --wifi-power${NC}"
}

ensure_profile

# Parsing de argumentos
if [ $# -eq 0 ]; then
    show_interactive_menu
    exit 0
fi

while [ $# -gt 0 ]; do
    case "$1" in
        --all)
            apply_all_detected
            exit 0
            ;;
        --keyboard)
            apply_keyboard
            shift
            ;;
        --autoheal)
            apply_autoheal
            shift
            ;;
        --wifi-power)
            apply_wifi_power
            shift
            ;;
        --keyboard-power)
            apply_keyboard_power
            shift
            ;;
        --gestures)
            apply_gestures
            shift
            ;;
        --mouse)
            apply_mouse
            shift
            ;;
        --screen-60)
            apply_screen_60
            shift
            ;;
        --screen-high)
            apply_screen_high
            shift
            ;;
        --tongfang)
            apply_tongfang
            shift
            ;;
        *)
            echo -e "${RED}Opção desconhecida: $1${NC}"
            echo "Uso: $0 [--all | --keyboard | --autoheal | --wifi-power | --keyboard-power | --gestures | --mouse | --screen-60 | --screen-high | --tongfang]"
            exit 1
            ;;
    esac
done
