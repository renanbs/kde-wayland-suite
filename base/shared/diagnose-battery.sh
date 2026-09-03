#!/usr/bin/env bash
set -uo pipefail

# ==============================================================================
# diagnose-battery.sh — Diagnóstico de consumo de energia/bateria
# Somente leitura: nunca aplica mudanças. Usado por configure-battery.sh e
# pelo agente de IA para decidir, junto com o usuário, o que aplicar.
# ==============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-battery-gpu.sh
source "$SCRIPT_DIR/lib-battery-gpu.sh"

# Flags de máquina lidas pelo agente de IA (uma linha "FINDING:<id>:<detail>" por achado acionável)
FINDINGS_FILE="${DIAGNOSE_BATTERY_FINDINGS_FILE:-}"
emit_finding() {
    if [ -n "$FINDINGS_FILE" ]; then
        echo "FINDING:$1:$2" >> "$FINDINGS_FILE"
    fi
}
[ -n "$FINDINGS_FILE" ] && : > "$FINDINGS_FILE"

echo -e "${BOLD}${BLUE}======================================================${NC}"
echo -e "${BOLD}${BLUE}   Diagnóstico de Bateria / Consumo de Energia        ${NC}"
echo -e "${BOLD}${BLUE}======================================================${NC}"
echo ""

# -----------------------------------------------------------------------------
# 1. Saúde e taxa de descarga da bateria
# -----------------------------------------------------------------------------
echo -e "${BOLD}[1/5] Bateria${NC}"
BAT_PATH="$(upower -e 2>/dev/null | grep -i battery | head -1 || true)"
if [ -n "$BAT_PATH" ]; then
    BAT_INFO="$(upower -i "$BAT_PATH" 2>/dev/null || true)"
    ENERGY_FULL="$(echo "$BAT_INFO" | grep -oP '(?<=energy-full:\s{1,20})[0-9.,]+' | tr ',' '.' || true)"
    ENERGY_DESIGN="$(echo "$BAT_INFO" | grep -oP '(?<=energy-full-design:\s{1,20})[0-9.,]+' | tr ',' '.' || true)"
    RATE="$(echo "$BAT_INFO" | grep -oP '(?<=energy-rate:\s{1,20})[0-9.,]+' | tr ',' '.' || true)"
    PERCENT="$(echo "$BAT_INFO" | grep -oP '(?<=percentage:\s{1,20})[0-9]+' || true)"
    STATE="$(echo "$BAT_INFO" | grep -oP '(?<=state:\s{1,20}).+' | sed -E 's/^[[:space:]]+//' || true)"

    if [ -n "$ENERGY_FULL" ] && [ -n "$ENERGY_DESIGN" ]; then
        HEALTH="$(awk -v f="$ENERGY_FULL" -v d="$ENERGY_DESIGN" 'BEGIN { if (d>0) printf "%.1f", f*100/d; else print "?" }')"
        echo -e "  • Capacidade real: ${ENERGY_FULL} Wh / projeto de fábrica: ${ENERGY_DESIGN} Wh (${BOLD}${HEALTH}%${NC} de saúde)"
        if awk -v h="$HEALTH" 'BEGIN { exit !(h+0 < 80) }' 2>/dev/null; then
            echo -e "    ${YELLOW}[INFO]${NC} Bateria com desgaste considerável. É degradação física da célula — não corrigível por software."
            emit_finding "battery_health_degraded" "health=${HEALTH}%"
        fi
    fi
    [ -n "$STATE" ] && [ -n "$RATE" ] && echo -e "  • Estado: $STATE | Taxa atual de consumo: ${BOLD}${RATE} W${NC} | Carga: ${PERCENT:-?}%"
else
    echo -e "  • ${YELLOW}[INFO]${NC} Nenhuma bateria detectada via upower (desktop ou upowerd ausente)."
fi

# Charge threshold (limite de carga, ex: parar em 80%)
THRESH_FILE="$(command ls /sys/class/power_supply/BAT*/charge_control_end_threshold 2>/dev/null | head -1 || true)"
if [ -n "$THRESH_FILE" ]; then
    echo -e "  • ${GREEN}[OK]${NC} Suporte a limite de carga disponível: $THRESH_FILE (atual: $(cat "$THRESH_FILE" 2>/dev/null))"
else
    echo -e "  • ${BLUE}[INFO]${NC} Sem suporte de fábrica/kernel a limite de carga (charge_control_end_threshold ausente) — comum em barebones sem driver de EC dedicado (ex: Clevo/Tongfang sem clevo-legion-linux)."
fi

# -----------------------------------------------------------------------------
# 2. GPU primária do compositor (KWin) vs. GPU que atende o painel interno
# -----------------------------------------------------------------------------
echo ""
echo -e "${BOLD}[2/5] GPU Primária do Compositor (híbrido Intel/NVIDIA/AMD)${NC}"

kwin_drm_locate

if [ -z "$KWIN_DRM_VALUE" ]; then
    echo -e "  • ${BLUE}[INFO]${NC} Nenhum KWIN_DRM_DEVICES customizado encontrado (sistema com GPU única, ou KWin escolhe automaticamente). Nada a avaliar aqui."
else
    FIRST_DEV="$(kwin_drm_split "$KWIN_DRM_VALUE" | head -1)"
    FIRST_CARD="$(basename "$(readlink -f "$FIRST_DEV" 2>/dev/null || echo "$FIRST_DEV")")"
    FIRST_PCI="$(pci_for_device_path "$FIRST_DEV")"

    read -r EDP_CARD EDP_PCI <<< "$(find_edp_card_pci)"

    if [ -z "$EDP_CARD" ]; then
        echo -e "  • ${BLUE}[INFO]${NC} Nenhuma saída eDP conectada encontrada (ex: desktop, ou painel via outra interface). Não é possível comparar automaticamente."
    else
        echo -e "  • Arquivo com KWIN_DRM_DEVICES: $KWIN_ENV_FILE"
        echo -e "  • GPU primária configurada (1ª da lista): $FIRST_CARD (PCI $FIRST_PCI)"
        echo -e "  • GPU que atende o painel interno (eDP): $EDP_CARD (PCI $EDP_PCI)"
        if [ "$FIRST_PCI" = "$EDP_PCI" ]; then
            echo -e "  • ${GREEN}[OK]${NC} A GPU primária do KWin já é a mesma que atende o painel interno. Sem cópia extra de frames entre GPUs."
        else
            echo -e "  • ${RED}[FALHA]${NC} A GPU primária do KWin (${FIRST_CARD}) é diferente da que atende o painel interno (${EDP_CARD})."
            echo -e "    Isso obriga o KWin a compor no ${FIRST_CARD} e copiar cada frame para o ${EDP_CARD} exibir — mantendo a GPU '${FIRST_CARD}' sempre ligada, mesmo sem uso real, e gastando energia extra à toa."
            emit_finding "gpu_primary_mismatch" "kwin_env_file=${KWIN_ENV_FILE};current_value=${KWIN_DRM_VALUE};edp_card=${EDP_CARD};edp_pci=${EDP_PCI}"
        fi
    fi
fi

# -----------------------------------------------------------------------------
# 3. PCIe ASPM (Active State Power Management)
# -----------------------------------------------------------------------------
echo ""
echo -e "${BOLD}[3/5] PCIe ASPM (economia de energia do barramento PCIe)${NC}"
ASPM_FILE="/sys/module/pcie_aspm/parameters/policy"
if [ -f "$ASPM_FILE" ]; then
    ASPM_RAW="$(cat "$ASPM_FILE" 2>/dev/null)"
    ASPM_CURRENT="$(echo "$ASPM_RAW" | grep -oP '(?<=\[)[a-z]+(?=\])')"
    echo -e "  • Política atual: ${BOLD}${ASPM_CURRENT}${NC} (opções: $ASPM_RAW)"
    if [ "$ASPM_CURRENT" = "performance" ] || [ "$ASPM_CURRENT" = "default" ]; then
        echo -e "  • ${YELLOW}[INFO]${NC} Política '${ASPM_CURRENT}' não é a mais econômica. 'powersave' permite que dispositivos PCIe (NVMe, Wi-Fi, GPU) entrem em estados de baixo consumo quando ociosos."
        echo -e "    ${YELLOW}Atenção${NC}: em raros casos, firmwares de NVMe/Wi-Fi com suporte a ASPM mal implementado podem ficar instáveis com 'powersave'. Reversível na hora (sysfs), sem necessidade de reboot."
        emit_finding "pcie_aspm_not_powersave" "current=${ASPM_CURRENT}"
    else
        echo -e "  • ${GREEN}[OK]${NC} Já em modo econômico."
    fi
else
    echo -e "  • ${BLUE}[INFO]${NC} $ASPM_FILE não existe (kernel sem suporte a ASPM configurável, ou desabilitado na BIOS)."
fi

# -----------------------------------------------------------------------------
# 4. Rádios e serviços ociosos
# -----------------------------------------------------------------------------
echo ""
echo -e "${BOLD}[4/5] Rádios e Serviços${NC}"
if systemctl is-active --quiet bluetooth.service 2>/dev/null; then
    BT_CONNECTED="$(bluetoothctl devices Connected 2>/dev/null || true)"
    if [ -z "$BT_CONNECTED" ]; then
        echo -e "  • ${YELLOW}[INFO]${NC} Bluetooth ativo, mas sem nenhum dispositivo conectado agora."
    else
        echo -e "  • ${GREEN}[OK]${NC} Bluetooth ativo com dispositivo(s) conectado(s)."
    fi
else
    echo -e "  • ${GREEN}[OK]${NC} Bluetooth desligado."
fi

if systemctl is-active --quiet docker.service 2>/dev/null; then
    N_CONTAINERS="$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')"
    echo -e "  • ${BLUE}[INFO]${NC} Docker daemon ativo (${N_CONTAINERS} container(s) rodando agora)."
else
    echo -e "  • ${GREEN}[OK]${NC} Docker daemon inativo."
fi

# -----------------------------------------------------------------------------
# 5. CPU
# -----------------------------------------------------------------------------
echo ""
echo -e "${BOLD}[5/5] CPU${NC}"
GOVERNOR="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo '?')"
PROFILE="$(powerprofilesctl get 2>/dev/null || echo '?')"
echo -e "  • Governor: $GOVERNOR | Perfil de energia (power-profiles-daemon): $PROFILE"

echo ""
echo -e "${BOLD}${BLUE}======================================================${NC}"
echo -e "${BOLD}${GREEN}✔ Diagnóstico concluído.${NC}"
echo -e "${BOLD}${BLUE}======================================================${NC}"
