#!/usr/bin/env bash
# ==============================================================================
# profile-machine.sh — Varredura, Diagnóstico e Machine Profile (Não-Destrutivo)
#
# Comportamento:
# - Inspeciona o hardware e o ambiente do sistema operacional sem fazer alterações.
# - Coleta dados de:
#   * Sistema Operacional, Kernel, Sessão Wayland/Compositor, AI Harness e Idioma
#   * Bateria, Fonte de Alimentação e Limite de Carga
#   * GPUs (iGPU / dGPU), KWin DRM Devices e Taxa de Atualização da Tela (Hz)
#   * Adaptador Wi-Fi, Drivers, Power Save e Barramento PCIe
#   * Teclado Integrado (i8042 / Tongfang), Mouses e Touchpad
# - Salva o perfil em:
#   ~/.config/linux-wayland-suite/machine-profile.json
# - Não requer privilégios de root (leitura pura).
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
PROFILE_DIR="${HOME}/.config/linux-wayland-suite"
PROFILE_FILE="${PROFILE_DIR}/machine-profile.json"

# Carrega helpers
if [ -f "$SCRIPT_DIR/lib-runlog.sh" ]; then
    # shellcheck source=lib-runlog.sh
    source "$SCRIPT_DIR/lib-runlog.sh"
else
    runlog_event() { :; }
    runlog_metric() { :; }
fi

if [ -f "$SCRIPT_DIR/lib-harness.sh" ]; then
    # shellcheck source=lib-harness.sh
    source "$SCRIPT_DIR/lib-harness.sh"
fi

if [ -f "$SCRIPT_DIR/lib-battery-gpu.sh" ]; then
    # shellcheck source=lib-battery-gpu.sh
    source "$SCRIPT_DIR/lib-battery-gpu.sh"
fi

echo -e "${BOLD}${BLUE}======================================================${NC}"
echo -e "${BOLD}${BLUE}   Linux Wayland Suite — Machine Profiler & Scan      ${NC}"
echo -e "${BOLD}${BLUE}======================================================${NC}\n"

# -----------------------------------------------------------------------------
# 1. Sistema Operacional, Sessão e Harness
# -----------------------------------------------------------------------------
echo -e "${BOLD}[1/5] Identificando Sistema, Sessão e Ambiente...${NC}"
HOSTNAME_STR="$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo 'localhost')"
KERNEL_STR="$(uname -r 2>/dev/null || echo 'unknown')"
ARCH_STR="$(uname -m 2>/dev/null || echo 'x86_64')"
SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"
DESKTOP="${XDG_CURRENT_DESKTOP:-unknown}"

DISTRO_ID="unknown"
DISTRO_NAME="Linux"
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_NAME="${PRETTY_NAME:-$NAME}"
fi

ACTIVE_HARNESS="terminal"
if declare -f detect_active_harness >/dev/null 2>&1; then
    ACTIVE_HARNESS="$(detect_active_harness)"
fi

ACTIVE_LANG="en"
if declare -f load_active_language >/dev/null 2>&1; then
    ACTIVE_LANG="$(load_active_language)"
fi

DMI_VENDOR="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo 'unknown')"
DMI_PRODUCT="$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo 'unknown')"
DMI_BOARD="$(cat /sys/class/dmi/id/board_name 2>/dev/null || echo 'unknown')"
CHASSIS_TYPE="$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo '0')"

# Chassis laptop: 8 (Portable), 9 (Laptop), 10 (Notebook), 11 (Hand Held), 12 (Docking Station), 14 (Sub Notebook), 31 (Convertible), 32 (Detachable)
IS_LAPTOP=0
if [[ "$CHASSIS_TYPE" =~ ^(8|9|10|11|12|14|31|32)$ ]]; then
    IS_LAPTOP=1
fi

echo -e "  • Hardware: ${BOLD}${DMI_VENDOR} / ${DMI_PRODUCT}${NC} (Placa: ${DMI_BOARD})"
echo -e "  • Sistema:  ${BOLD}${DISTRO_NAME}${NC} (Kernel ${KERNEL_STR}, ${ARCH_STR})"
echo -e "  • Sessão:   ${BOLD}${DESKTOP}${NC} (${SESSION_TYPE})"
echo -e "  • Harness:  ${BOLD}${ACTIVE_HARNESS}${NC} (Idioma: ${ACTIVE_LANG})"

# -----------------------------------------------------------------------------
# 2. Bateria e Energia
# -----------------------------------------------------------------------------
echo -e "\n${BOLD}[2/5] Inspecionando Bateria e Gerenciamento de Energia...${NC}"
HAS_BATTERY=0
BAT_HEALTH="null"
BAT_RATE="null"
BAT_STATE="null"
BAT_CHARGE="null"
CURRENT_SOURCE="AC"

# Detecção de fonte de energia
HAS_AC=0
for s in /sys/class/power_supply/*; do
    [ -d "$s" ] || continue
    s_type="$(cat "$s/type" 2>/dev/null || echo '')"
    if [[ "$s_type" =~ ^(Mains|AC|ADP[0-9]*)$ ]]; then
        if [ "$(cat "$s/online" 2>/dev/null || echo '0')" = "1" ]; then
            HAS_AC=1
        fi
    elif [[ "$s_type" == "Battery" ]]; then
        HAS_BATTERY=1
    fi
done

if [ "$HAS_AC" -eq 1 ]; then
    CURRENT_SOURCE="AC"
elif [ "$HAS_BATTERY" -eq 1 ]; then
    CURRENT_SOURCE="BATTERY"
else
    CURRENT_SOURCE="AC"
fi

if command -v upower >/dev/null 2>&1; then
    BAT_PATH="$(upower -e 2>/dev/null | grep -i battery | head -1 || true)"
    if [ -n "$BAT_PATH" ]; then
        HAS_BATTERY=1
        BAT_INFO="$(upower -i "$BAT_PATH" 2>/dev/null || true)"
        E_FULL="$(echo "$BAT_INFO" | grep -oP '(?<=energy-full:\s{1,20})[0-9.,]+' | tr ',' '.' || true)"
        E_DESIGN="$(echo "$BAT_INFO" | grep -oP '(?<=energy-full-design:\s{1,20})[0-9.,]+' | tr ',' '.' || true)"
        RATE_RAW="$(echo "$BAT_INFO" | grep -oP '(?<=energy-rate:\s{1,20})[0-9.,]+' | tr ',' '.' || true)"
        PCT_RAW="$(echo "$BAT_INFO" | grep -oP '(?<=percentage:\s{1,20})[0-9]+' || true)"
        ST_RAW="$(echo "$BAT_INFO" | grep -oP '(?<=state:\s{1,20}).+' | sed -E 's/^[[:space:]]+//' || true)"

        [ -n "$RATE_RAW" ] && BAT_RATE="$RATE_RAW"
        [ -n "$PCT_RAW" ] && BAT_CHARGE="$PCT_RAW"
        [ -n "$ST_RAW" ] && BAT_STATE="$ST_RAW"

        if [ -n "$E_FULL" ] && [ -n "$E_DESIGN" ]; then
            BAT_HEALTH="$(awk -v f="$E_FULL" -v d="$E_DESIGN" 'BEGIN { if (d>0) printf "%.1f", f*100/d; else print "null" }')"
        fi
    fi
fi

THRESH_SUPPORT=0
if ls /sys/class/power_supply/BAT*/charge_control_end_threshold >/dev/null 2>&1; then
    THRESH_SUPPORT=1
fi

if [ "$HAS_BATTERY" -eq 1 ]; then
    echo -e "  • Bateria: Presente | Saúde: ${BOLD}${BAT_HEALTH}%${NC} | Carga: ${BAT_CHARGE}% (${BAT_STATE})"
    echo -e "  • Fonte de Alimentação Atual: ${BOLD}${CURRENT_SOURCE}${NC}"
else
    echo -e "  • Bateria: Não detectada (Desktop / Mini-PC ou Alimentação AC Direta)"
    echo -e "  • Fonte de Alimentação Atual: ${BOLD}${CURRENT_SOURCE}${NC}"
fi

# -----------------------------------------------------------------------------
# 3. GPUs, Compositor e Taxa de Atualização da Tela
# -----------------------------------------------------------------------------
echo -e "\n${BOLD}[3/5] Inspecionando Placas de Vídeo e Tela Interna...${NC}"
kwin_drm_locate
EDP_CARD=""
EDP_PCI=""
read -r EDP_CARD EDP_PCI <<< "$(find_edp_card_pci || true)"

KWIN_MISMATCH=0
if [ -n "$KWIN_DRM_VALUE" ] && [ -n "$EDP_PCI" ]; then
    FIRST_DEV="$(kwin_drm_split "$KWIN_DRM_VALUE" | head -1)"
    FIRST_PCI="$(pci_for_device_path "$FIRST_DEV")"
    if [ "$FIRST_PCI" != "$EDP_PCI" ]; then
        KWIN_MISMATCH=1
    fi
fi

# Tela interna (eDP) refresh modes
EDP_NAME=""
EDP_CUR_HZ=""
EDP_CUR_MODE=""
EDP_60_ID=""
EDP_HIGH_ID=""
if declare -f find_edp_refresh_modes >/dev/null 2>&1; then
    read -r EDP_NAME EDP_CUR_HZ EDP_CUR_MODE EDP_60_ID EDP_HIGH_ID <<< "$(find_edp_refresh_modes || true)"
fi

# GPUs no sistema
GPUS_INFO=()
for card_path in /sys/class/drm/card[0-9]; do
    [ -d "$card_path" ] || continue
    card_name="$(basename "$card_path")"
    pci_addr="$(readlink -f "$card_path/device" 2>/dev/null | xargs -r basename || echo '')"
    driver_name="$(basename "$(readlink -f "$card_path/device/driver" 2>/dev/null || echo '')")"
    vendor_id="$(cat "$card_path/device/vendor" 2>/dev/null || echo '')"

    v_name="Outro"
    case "$vendor_id" in
        0x8086) v_name="Intel" ;;
        0x10de) v_name="NVIDIA" ;;
        0x1002) v_name="AMD" ;;
    esac

    is_panel_gpu=0
    [ -n "$EDP_PCI" ] && [ "$pci_addr" = "$EDP_PCI" ] && is_panel_gpu=1

    GPUS_INFO+=("${v_name}|${card_name}|${pci_addr}|${driver_name}|${is_panel_gpu}")
    echo -e "  • GPU: ${BOLD}${v_name}${NC} (${card_name}, PCI ${pci_addr}, driver ${driver_name}) $([ "$is_panel_gpu" -eq 1 ] && echo -e "${CYAN}[Painel Interno]${NC}")"
done

MODE_60_REJECTED=0
if [ -f "$PROFILE_FILE" ]; then
    if python3 -c "import json, os; d=json.load(open(os.path.expanduser('$PROFILE_FILE'))); exit(0 if d.get('display', {}).get('mode_60_rejected') else 1)" 2>/dev/null; then
        MODE_60_REJECTED=1
    fi
fi

if [ -n "$EDP_NAME" ] && [ "$EDP_NAME" != "unknown" ]; then
    if [ "$MODE_60_REJECTED" -eq 1 ]; then
        echo -e "  • Tela Interna: ${BOLD}${EDP_NAME}${NC} | Taxa atual: ${BOLD}${EDP_CUR_HZ} Hz${NC} (Taxa nativa fixa, driver rejeita 60 Hz)"
    else
        echo -e "  • Tela Interna: ${BOLD}${EDP_NAME}${NC} | Taxa atual: ${BOLD}${EDP_CUR_HZ} Hz${NC} (Modo 60Hz: ${EDP_60_ID}, Modo Alta Taxa: ${EDP_HIGH_ID})"
    fi
fi

# -----------------------------------------------------------------------------
# 4. Wi-Fi e Conexão de Rede
# -----------------------------------------------------------------------------
echo -e "\n${BOLD}[4/5] Inspecionando Placa Wi-Fi e Gerenciamento de Energia...${NC}"
WIFI_IFACES=()
for iface_path in /sys/class/net/*; do
    [ -d "$iface_path" ] || continue
    if [ -d "$iface_path/wireless" ] || [ -d "$iface_path/phy80211" ]; then
        WIFI_IFACES+=("$(basename "$iface_path")")
    fi
done

SMART_WIFI_INSTALLED=0
if [ -f "/etc/udev/rules.d/90-linux-wayland-smart-wifi-power.rules" ]; then
    SMART_WIFI_INSTALLED=1
fi

WIFI_DATA=()
if [ ${#WIFI_IFACES[@]} -eq 0 ]; then
    echo -e "  • Wi-Fi: Nenhuma interface de rede sem fio detectada"
else
    for wif in "${WIFI_IFACES[@]}"; do
        w_driver="$(basename "$(readlink -f "/sys/class/net/$wif/device/driver" 2>/dev/null || echo 'unknown')")"
        w_pci="$(readlink -f "/sys/class/net/$wif/device" 2>/dev/null | xargs -r basename || echo 'unknown')"
        w_pwr_file="$(readlink -f "/sys/class/net/$wif/device/power/control" 2>/dev/null || echo '')"
        w_pm_status="unknown"
        [ -f "$w_pwr_file" ] && w_pm_status="$(cat "$w_pwr_file" 2>/dev/null || echo 'unknown')"

        w_ps="unknown"
        if command -v iw >/dev/null 2>&1; then
            if iw dev "$wif" get power_save 2>/dev/null | grep -qi "on"; then
                w_ps="on"
            elif iw dev "$wif" get power_save 2>/dev/null | grep -qi "off"; then
                w_ps="off"
            fi
        fi

        WIFI_DATA+=("${wif}|${w_driver}|${w_pci}|${w_ps}|${w_pm_status}")
        echo -e "  • Interface: ${BOLD}${wif}${NC} (Driver: ${w_driver}, PCI: ${w_pci})"
        echo -e "    - 802.11 Power Save: ${BOLD}${w_ps}${NC} | PCIe Runtime PM: ${w_pm_status}"
    done
    if [ "$SMART_WIFI_INSTALLED" -eq 1 ]; then
        echo -e "  • Smart Wi-Fi Power: ${GREEN}[ATIVO]${NC} (Alternância automática AC vs Bateria instalada)"
    else
        echo -e "  • Smart Wi-Fi Power: ${YELLOW}[INATIVO]${NC} (Disponível para configuração)"
    fi
fi

# -----------------------------------------------------------------------------
# 5. Teclado, Touchpad e Dispositivos de Entrada
# -----------------------------------------------------------------------------
echo -e "\n${BOLD}[5/5] Inspecionando Teclado, Touchpad e Dispositivos de Entrada...${NC}"

# Tongfang / Avell / Clevo
IS_TONGFANG=0
if echo "${DMI_VENDOR} ${DMI_PRODUCT} ${DMI_BOARD}" | grep -qiE "Tongfang|Avell|Clevo|Schenker|XMG|Mechrevo|Machenike|Hasee|PCSpecialist"; then
    IS_TONGFANG=1
fi

TONGFANG_UNLOCKED=0
if grep -q "i8042.dumbkbd=1" /proc/cmdline 2>/dev/null; then
    TONGFANG_UNLOCKED=1
fi

I8042_PRESENT=0
[ -f /sys/devices/platform/i8042/serio0/power/control ] && I8042_PRESENT=1

SMART_KBD_INSTALLED=0
[ -f /etc/udev/rules.d/90-kde-smart-keyboard-power.rules ] && SMART_KBD_INSTALLED=1

TOUCHPAD_PRESENT=0
for n in /sys/class/input/input*/name; do
    [ -f "$n" ] || continue
    if grep -qiE "touchpad|synaptics|alps|elan|glidepoint" "$n" 2>/dev/null; then
        TOUCHPAD_PRESENT=1
        break
    fi
done

MX_MASTER_PRESENT=0
for n in /sys/class/input/input*/name; do
    [ -f "$n" ] || continue
    if grep -qi "MX Master" "$n" 2>/dev/null; then
        MX_MASTER_PRESENT=1
        break
    fi
done

AUTOHEAL_INSTALLED=0
if [ -f "$HOME/.config/autostart/kde-wayland-suite-restore-layout.desktop" ] || [ -f "$HOME/.config/autostart/linux-wayland-layout-autoheal.desktop" ]; then
    AUTOHEAL_INSTALLED=1
fi
CHROMIUM_APPS=()
if [ -f "$SCRIPT_DIR/manage-chromium-cedilla.sh" ]; then
    while IFS= read -r app_path; do
        [ -n "$app_path" ] && CHROMIUM_APPS+=("$app_path")
    done <<< "$("$SCRIPT_DIR/manage-chromium-cedilla.sh" --discover 2>/dev/null || true)"
fi

echo -e "  • Barramento i8042: $([ "$I8042_PRESENT" -eq 1 ] && echo -e "${GREEN}Presente${NC}" || echo -e "Ausente")"
if [ "$IS_TONGFANG" -eq 1 ]; then
    echo -e "  • Chassis Tongfang/Avell: ${BOLD}Detectado${NC} (Desbloqueio GRUB: $([ "$TONGFANG_UNLOCKED" -eq 1 ] && echo -e "${GREEN}[OK]${NC}" || echo -e "${YELLOW}[Pendente]${NC}"))"
fi
echo -e "  • Touchpad: $([ "$TOUCHPAD_PRESENT" -eq 1 ] && echo -e "${GREEN}Detectado${NC}" || echo -e "Não detectado")"
echo -e "  • Mouse Logitech MX Master 3S: $([ "$MX_MASTER_PRESENT" -eq 1 ] && echo -e "${GREEN}Detectado${NC}" || echo -e "Não detectado")"
echo -e "  • Layout Auto-Heal (Proteção KWin): $([ "$AUTOHEAL_INSTALLED" -eq 1 ] && echo -e "${GREEN}[INSTALADO]${NC}" || echo -e "${YELLOW}[NÃO INSTALADO]${NC}")"
echo -e "  • Apps Chromium/Electron detectados: ${BOLD}${#CHROMIUM_APPS[@]}${NC} app(s)"

# -----------------------------------------------------------------------------
# 6. Gravação Estruturada do Machine Profile (JSON)
# -----------------------------------------------------------------------------
mkdir -p "$PROFILE_DIR"

python3 -c "
import json, sys, os

profile = {
    'version': '1.0.0',
    'timestamp': '$(date -Iseconds)',
    'system': {
        'hostname': '$HOSTNAME_STR',
        'distro_id': '$DISTRO_ID',
        'distro_name': '$DISTRO_NAME',
        'kernel': '$KERNEL_STR',
        'arch': '$ARCH_STR',
        'session_type': '$SESSION_TYPE',
        'desktop': '$DESKTOP',
        'active_harness': '$ACTIVE_HARNESS',
        'active_language': '$ACTIVE_LANG'
    },
    'dmi': {
        'vendor': '$DMI_VENDOR',
        'product': '$DMI_PRODUCT',
        'board': '$DMI_BOARD',
        'chassis_type': '$CHASSIS_TYPE',
        'is_laptop': bool($IS_LAPTOP)
    },
    'power': {
        'has_battery': bool($HAS_BATTERY),
        'current_source': '$CURRENT_SOURCE',
        'battery_health_percent': float('$BAT_HEALTH') if '$BAT_HEALTH' != 'null' else None,
        'battery_charge_percent': int('$BAT_CHARGE') if '$BAT_CHARGE' != 'null' and '$BAT_CHARGE'.isdigit() else None,
        'battery_state': '$BAT_STATE' if '$BAT_STATE' != 'null' else None,
        'charge_threshold_supported': bool($THRESH_SUPPORT)
    },
    'display': {
        'edp_name': '$EDP_NAME' if '$EDP_NAME' and '$EDP_NAME' != 'unknown' else None,
        'current_hz': int('$EDP_CUR_HZ') if '$EDP_CUR_HZ' and '$EDP_CUR_HZ'.isdigit() else None,
        'mode_60_available': False if bool($MODE_60_REJECTED) else bool('$EDP_60_ID' and '$EDP_60_ID' != 'none'),
        'mode_60_rejected': bool($MODE_60_REJECTED),
        'mode_high_available': bool('$EDP_HIGH_ID' and '$EDP_HIGH_ID' != 'none'),
        'kwin_gpu_mismatch': bool($KWIN_MISMATCH),
        'kwin_drm_configured': r'''$KWIN_DRM_VALUE''' if r'''$KWIN_DRM_VALUE''' else None
    },
    'wifi': {
        'interfaces': [
            {
                'name': item.split('|')[0],
                'driver': item.split('|')[1],
                'pci': item.split('|')[2],
                'power_save': item.split('|')[3],
                'pci_power_pm': item.split('|')[4]
            }
            for item in '''$(printf '%s\n' "${WIFI_DATA[@]:-}")'''.strip().splitlines() if item
        ],
        'smart_wifi_power_installed': bool($SMART_WIFI_INSTALLED)
    },
    'input': {
        'i8042_present': bool($I8042_PRESENT),
        'is_tongfang_candidate': bool($IS_TONGFANG),
        'tongfang_grub_unlocked': bool($TONGFANG_UNLOCKED),
        'smart_keyboard_power_installed': bool($SMART_KBD_INSTALLED),
        'touchpad_present': bool($TOUCHPAD_PRESENT),
        'mx_master_present': bool($MX_MASTER_PRESENT),
        'layout_autoheal_installed': bool($AUTOHEAL_INSTALLED)
    },
    'chromium_apps': {
        'count': len('''$(printf '%s\n' "${CHROMIUM_APPS[@]:-}")'''.strip().splitlines()) if '''$(printf '%s\n' "${CHROMIUM_APPS[@]:-}")'''.strip() else 0,
        'installed_binaries': [p for p in '''$(printf '%s\n' "${CHROMIUM_APPS[@]:-}")'''.strip().splitlines() if p],
        'cedilla_hook_installed': os.path.exists('/etc/pacman.d/hooks/99-cedilla-wayland.hook')
    }
}

target_file = os.path.expanduser('$PROFILE_FILE')
with open(target_file, 'w', encoding='utf-8') as f:
    json.dump(profile, f, indent=2, ensure_ascii=False)
"

runlog_event "ok" "machine_profile_saved" "$PROFILE_FILE"
echo -e "\n${BOLD}${GREEN}✔ Perfil da máquina salvo com sucesso em:${NC} ${BOLD}${PROFILE_FILE}${NC}"
echo -e "\n${BOLD}Para configurar e aplicar as otimizações recomendadas:${NC}"
echo -e "  Execute: ${BOLD}./bin/linux-wayland-config setup${NC} (ou 'make setup')\n"
