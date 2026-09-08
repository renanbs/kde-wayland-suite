#!/usr/bin/env bash
# ==============================================================================
# manage-wifi-power.sh — Gerenciamento Inteligente de Energia do Wi-Fi (AC vs Bateria)
#
# Comportamento:
# - Na Tomada (AC):
#   * Desativa o Power Save 802.11 da interface Wi-Fi ('iw dev <iface> set power_save off')
#   * Define /sys/bus/pci/devices/<pci_id>/power/control = "on" (impede dormência D3hot)
#   * Garante baixa latência e estabilidade para conexões de entrada (Orca, SSH, streaming).
# - Na Bateria:
#   * Ativa o Power Save 802.11 ('iw dev <iface> set power_save on')
#   * Define power/control = "auto" para máxima economia de energia.
# - Ao reconectar ou voltar do Sleep:
#   * Gancho no systemd-sleep e dispatcher do NetworkManager garantem sincronização imediata.
#
# Suporta:
#   --sync         Executa a verificação e ajusta o estado imediatamente
#   --apply-udev   Instala regras udev, dispatcher NetworkManager e gancho systemd-sleep
#   --remove-udev  Remove as regras e restaura a política padrão do sistema
#   --status       Exibe o estado atual da interface, rádio e ganchos
# ==============================================================================
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UDEV_RULE_FILE="/etc/udev/rules.d/90-linux-wayland-smart-wifi-power.rules"
NM_DISPATCHER_DIR="/etc/NetworkManager/dispatcher.d"
NM_DISPATCHER_FILE="${NM_DISPATCHER_DIR}/90-linux-wayland-smart-wifi-power.sh"
SLEEP_HOOK_DIR="/etc/systemd/system-sleep"
SLEEP_HOOK_FILE="${SLEEP_HOOK_DIR}/90-linux-wayland-wifi-resume.sh"

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

get_wifi_interfaces() {
    local ifaces=()
    for iface_path in /sys/class/net/*; do
        [ -d "$iface_path" ] || continue
        if [ -d "$iface_path/wireless" ] || [ -d "$iface_path/phy80211" ]; then
            local name
            name="$(basename "$iface_path")"
            ifaces+=("$name")
        fi
    done
    echo "${ifaces[@]}"
}

get_power_source() {
    local has_ac=0
    local has_battery=0

    for supply in /sys/class/power_supply/*; do
        [ -d "$supply" ] || continue
        local type_file="$supply/type"
        [ -f "$type_file" ] || continue
        local p_type
        p_type="$(cat "$type_file" 2>/dev/null || echo '')"

        if [[ "$p_type" =~ ^(Mains|AC|ADP[0-9]*)$ ]]; then
            local online_file="$supply/online"
            if [ -f "$online_file" ]; then
                local online_val
                online_val="$(cat "$online_file" 2>/dev/null || echo '0')"
                if [ "$online_val" = "1" ]; then
                    has_ac=1
                fi
            fi
        elif [[ "$p_type" == "Battery" ]]; then
            has_battery=1
        fi
    done

    if [ "$has_ac" -eq 1 ]; then
        echo "AC"
    elif [ "$has_battery" -eq 1 ]; then
        echo "BATTERY"
    else
        # Sem bateria física (Desktop / Mini-PC) -> assume AC permanente
        echo "AC"
    fi
}

get_device_power_path() {
    local iface="$1"
    local dev_link="/sys/class/net/$iface/device"
    if [ -L "$dev_link" ] || [ -d "$dev_link" ]; then
        local real_dev
        real_dev="$(readlink -f "$dev_link" 2>/dev/null || true)"
        if [ -n "$real_dev" ] && [ -f "$real_dev/power/control" ]; then
            echo "$real_dev/power/control"
        fi
    fi
}

get_wifi_driver() {
    local iface="$1"
    local driver_link="/sys/class/net/$iface/device/driver"
    if [ -L "$driver_link" ]; then
        basename "$(readlink -f "$driver_link" 2>/dev/null || echo 'unknown')"
    else
        echo "unknown"
    fi
}

get_power_save_state() {
    local iface="$1"
    if command -v iw >/dev/null 2>&1; then
        local state
        state="$(iw dev "$iface" get power_save 2>/dev/null || echo '')"
        if echo "$state" | grep -qi "on"; then
            echo "on"
            return 0
        elif echo "$state" | grep -qi "off"; then
            echo "off"
            return 0
        fi
    fi

    if command -v iwconfig >/dev/null 2>&1; then
        local iw_out
        iw_out="$(iwconfig "$iface" 2>/dev/null || echo '')"
        if echo "$iw_out" | grep -qi "Power Management:off"; then
            echo "off"
            return 0
        elif echo "$iw_out" | grep -qi "Power Management:on"; then
            echo "on"
            return 0
        fi
    fi

    echo "unknown"
}

set_wifi_power_save() {
    local iface="$1"
    local target_state="$2" # on | off

    if command -v iw >/dev/null 2>&1; then
        iw dev "$iface" set power_save "$target_state" 2>/dev/null || true
    fi

    if command -v iwconfig >/dev/null 2>&1; then
        iwconfig "$iface" power "$target_state" 2>/dev/null || true
    fi
}

cmd_sync() {
    local pwr_source
    pwr_source="$(get_power_source)"
    local ifaces_str
    ifaces_str="$(get_wifi_interfaces)"

    if [ -z "$ifaces_str" ]; then
        echo -e "${YELLOW}[AVISO]${NC} Nenhuma interface Wi-Fi detectada neste sistema."
        runlog_event "skip" "wifi_power_no_interface" ""
        return 0
    fi

    read -r -a ifaces <<< "$ifaces_str"

    for iface in "${ifaces[@]}"; do
        local driver
        driver="$(get_wifi_driver "$iface")"
        local pwr_file
        pwr_file="$(get_device_power_path "$iface")"

        if [ "$pwr_source" = "AC" ]; then
            # Na tomada -> Desativa economia de energia para estabilidade e zero-latency
            set_wifi_power_save "$iface" "off"
            if [ -n "$pwr_file" ] && [ -w "$pwr_file" ]; then
                echo "on" > "$pwr_file" 2>/dev/null || true
            fi
            echo -e "  • ${GREEN}[OK]${NC} [$iface / $driver]: Modo AC (Tomada). Power save 802.11 alterado para: ${BOLD}off${NC} (zero latência / anti-sleep)."
            runlog_event "ok" "wifi_power_ac_active" "iface=$iface driver=$driver"
        else
            # Na bateria -> Ativa economia máxima
            set_wifi_power_save "$iface" "on"
            if [ -n "$pwr_file" ] && [ -w "$pwr_file" ]; then
                echo "auto" > "$pwr_file" 2>/dev/null || true
            fi
            echo -e "  • ${GREEN}[OK]${NC} [$iface / $driver]: Modo Bateria. Power save 802.11 alterado para: ${BOLD}on${NC} (economia de bateria)."
            runlog_event "ok" "wifi_power_battery_active" "iface=$iface driver=$driver"
        fi
    done
}

cmd_apply_udev() {
    check_root "$@"

    echo -e "${BOLD}### 1. Plano${NC}\n"
    echo -e "- **Comando:** ./bin/linux-wayland-config smart-wifi-power --apply"
    echo -e "- **Faz:** Instala regra udev dinâmica (${UDEV_RULE_FILE}), dispatcher do NetworkManager (${NM_DISPATCHER_FILE}) e gancho systemd-sleep (${SLEEP_HOOK_FILE}) para alternar automaticamente o power save do Wi-Fi entre AC (desligado/alta performance) e Bateria (ligado/economia)"
    echo -e "- **Reversível:** Sim, via './bin/linux-wayland-config smart-wifi-power --remove'\n"

    echo -e "${BOLD}### 2. Execução${NC}\n"

    echo -e "  [*] [1/5] Gravando regra udev dinâmica em ${BOLD}${UDEV_RULE_FILE}${NC}..."
    cat << EOF > "$UDEV_RULE_FILE"
# Regra Dinâmica de Energia Wi-Fi (Linux Wayland Suite)
# Alterna Power Save 802.11 e PCIe Runtime PM automaticamente na conexão/desconexão do carregador
SUBSYSTEM=="power_supply", ATTR{type}=="Mains|ADP[0-9]*", ACTION=="change", RUN+="/bin/sh -c 'if [ -x \"$SCRIPT_DIR/manage-wifi-power.sh\" ]; then \"$SCRIPT_DIR/manage-wifi-power.sh\" --sync; fi'"
EOF
    echo -e "  ✅ [1/5] Regra udev gravada com sucesso"
    runlog_event "ok" "smart_wifi_udev_created" "$UDEV_RULE_FILE"

    echo -e "  [*] [2/5] Gravando gancho do NetworkManager Dispatcher em ${BOLD}${NM_DISPATCHER_FILE}${NC}..."
    mkdir -p "$NM_DISPATCHER_DIR"
    cat << EOF > "$NM_DISPATCHER_FILE"
#!/bin/sh
# Gancho de Sincronização de Energia Wi-Fi do NetworkManager (Linux Wayland Suite)
case "\$2" in
    up|reapply)
        if [ -x "$SCRIPT_DIR/manage-wifi-power.sh" ]; then
            "$SCRIPT_DIR/manage-wifi-power.sh" --sync >/dev/null 2>&1 || true
        fi
        ;;
esac
EOF
    chmod +x "$NM_DISPATCHER_FILE"
    echo -e "  ✅ [2/5] Dispatcher do NetworkManager instalado e ativado"
    runlog_event "ok" "smart_wifi_dispatcher_created" "$NM_DISPATCHER_FILE"

    echo -e "  [*] [3/5] Gravando gancho de retorno de suspensão (Wake / Resume) em ${BOLD}${SLEEP_HOOK_FILE}${NC}..."
    mkdir -p "$SLEEP_HOOK_DIR"
    cat << EOF > "$SLEEP_HOOK_FILE"
#!/bin/sh
# Gancho de Retorno de Suspensão Wi-Fi (Linux Wayland Suite)
case "\$1/\$2" in
    post/*)
        if [ -x "$SCRIPT_DIR/manage-wifi-power.sh" ]; then
            "$SCRIPT_DIR/manage-wifi-power.sh" --sync >/dev/null 2>&1 || true
        fi
        ;;
esac
EOF
    chmod +x "$SLEEP_HOOK_FILE"
    echo -e "  ✅ [3/5] Gancho de retorno de suspensão systemd-sleep instalado e ativado"
    runlog_event "ok" "smart_wifi_sleep_hook_created" "$SLEEP_HOOK_FILE"

    echo -e "  [*] [4/5] Recarregando regras do udev..."
    udevadm control --reload-rules
    echo -e "  ✅ [4/5] Regras do udev recarregadas"
    runlog_event "ok" "udev_rules_reloaded" ""

    echo -e "  [*] [5/5] Executando sincronização imediata de estado..."
    cmd_sync
    echo -e "  ✅ [5/5] Estado de energia sincronizado"

    echo -e "\n${BOLD}### 3. Resumo${NC}\n"
    echo -e "| Campo | Conteúdo |"
    echo -e "| :--- | :--- |"
    echo -e "| O que mudou | Regra udev, dispatcher NetworkManager e gancho systemd-sleep instalados |"
    echo -e "| O que não mudou | Credenciais de rede, SSIDs e configurações do KWin |"
    echo -e "| Backup | Não aplicável (novos arquivos de automação do sistema) |"
    echo -e "| Relatório salvo | ./bin/linux-wayland-config report (ou ~/.local/state/linux-wayland-suite/runs/) |"
    echo -e "| Como reverter | ./bin/linux-wayland-config smart-wifi-power --remove |"
    echo -e "| Requer | nada (entra em vigor imediatamente) |"
}

cmd_remove_udev() {
    check_root "$@"

    echo -e "${BOLD}### 1. Plano${NC}\n"
    echo -e "- **Comando:** ./bin/linux-wayland-config smart-wifi-power --remove"
    echo -e "- **Faz:** Remove a regra udev dinâmica, dispatcher do NetworkManager e gancho de suspensão, restaurando a política padrão do sistema"
    echo -e "- **Reversível:** Sim, via './bin/linux-wayland-config smart-wifi-power --apply'\n"

    echo -e "${BOLD}### 2. Execução${NC}\n"

    if [ -f "$UDEV_RULE_FILE" ]; then
        rm -f "$UDEV_RULE_FILE"
        echo -e "  ✅ [1/4] Arquivo udev ${UDEV_RULE_FILE} removido"
        runlog_event "ok" "smart_wifi_udev_removed" "$UDEV_RULE_FILE"
    else
        echo -e "  ⏭️ [1/4] Arquivo ${UDEV_RULE_FILE} não existia"
    fi

    if [ -f "$NM_DISPATCHER_FILE" ]; then
        rm -f "$NM_DISPATCHER_FILE"
        echo -e "  ✅ [2/4] Dispatcher NetworkManager ${NM_DISPATCHER_FILE} removido"
        runlog_event "ok" "smart_wifi_dispatcher_removed" "$NM_DISPATCHER_FILE"
    else
        echo -e "  ⏭️ [2/4] Arquivo ${NM_DISPATCHER_FILE} não existia"
    fi

    if [ -f "$SLEEP_HOOK_FILE" ]; then
        rm -f "$SLEEP_HOOK_FILE"
        echo -e "  ✅ [3/4] Gancho systemd-sleep ${SLEEP_HOOK_FILE} removido"
        runlog_event "ok" "smart_wifi_sleep_hook_removed" "$SLEEP_HOOK_FILE"
    else
        echo -e "  ⏭️ [3/4] Gancho ${SLEEP_HOOK_FILE} não existia"
    fi

    udevadm control --reload-rules
    # Restaura power save padrão da interface (on)
    local ifaces_str
    ifaces_str="$(get_wifi_interfaces)"
    if [ -n "$ifaces_str" ]; then
        read -r -a ifaces <<< "$ifaces_str"
        for iface in "${ifaces[@]}"; do
            set_wifi_power_save "$iface" "on"
            local pwr_file
            pwr_file="$(get_device_power_path "$iface")"
            [ -n "$pwr_file" ] && [ -w "$pwr_file" ] && echo "auto" > "$pwr_file" 2>/dev/null || true
        done
    fi
    echo -e "  ✅ [4/4] Regras recarregadas e Wi-Fi restaurado ao padrão de fábrica"
    runlog_event "ok" "udev_rules_reloaded" ""

    echo -e "\n${BOLD}### 3. Resumo${NC}\n"
    echo -e "| Campo | Conteúdo |"
    echo -e "| :--- | :--- |"
    echo -e "| O que mudou | Regra udev, dispatcher e gancho de suspensão removidos |"
    echo -e "| O que não mudou | Conexões de rede salvas |"
    echo -e "| Backup | nenhum |"
    echo -e "| Relatório salvo | ./bin/linux-wayland-config report (ou ~/.local/state/linux-wayland-suite/runs/) |"
    echo -e "| Como reverter | ./bin/linux-wayland-config smart-wifi-power --apply |"
    echo -e "| Requer | nada |"
}

cmd_status() {
    echo -e "${BOLD}=== STATUS DO GERENCIAMENTO DE ENERGIA WI-FI ===${NC}"
    local pwr_source
    pwr_source="$(get_power_source)"
    echo -e "  • Fonte de Energia Atual:  ${BOLD}${pwr_source}${NC}"

    local ifaces_str
    ifaces_str="$(get_wifi_interfaces)"
    if [ -z "$ifaces_str" ]; then
        echo -e "  • Interfaces Wi-Fi:        ${YELLOW}Nenhuma detectada${NC}"
    else
        read -r -a ifaces <<< "$ifaces_str"
        for iface in "${ifaces[@]}"; do
            local driver
            driver="$(get_wifi_driver "$iface")"
            local ps_state
            ps_state="$(get_power_save_state "$iface")"
            local pwr_file
            pwr_file="$(get_device_power_path "$iface")"
            local pci_status="unknown"
            [ -n "$pwr_file" ] && [ -f "$pwr_file" ] && pci_status="$(cat "$pwr_file" 2>/dev/null || echo 'unknown')"

            echo -e "  • Interface:               ${BOLD}${iface}${NC} (Driver: ${driver})"
            echo -e "    - 802.11 Power Save:     ${BOLD}${ps_state}${NC}"
            echo -e "    - Barramento Power PM:   ${BOLD}${pci_status}${NC} (${pwr_file:-N/A})"
        done
    fi

    if [ -f "$UDEV_RULE_FILE" ]; then
        echo -e "  • Regra Dinâmica udev:     ${GREEN}[ATIVA]${NC} (${UDEV_RULE_FILE})"
    else
        echo -e "  • Regra Dinâmica udev:     ${YELLOW}[INATIVA]${NC} (Execute './bin/linux-wayland-config smart-wifi-power --apply')"
    fi

    if [ -f "$NM_DISPATCHER_FILE" ] && [ -x "$NM_DISPATCHER_FILE" ]; then
        echo -e "  • Dispatcher NetworkMgr:   ${GREEN}[ATIVO]${NC} (${NM_DISPATCHER_FILE})"
    else
        echo -e "  • Dispatcher NetworkMgr:   ${YELLOW}[INATIVO]${NC}"
    fi

    if [ -f "$SLEEP_HOOK_FILE" ] && [ -x "$SLEEP_HOOK_FILE" ]; then
        echo -e "  • Gancho systemd-sleep:    ${GREEN}[ATIVO]${NC} (${SLEEP_HOOK_FILE})"
    else
        echo -e "  • Gancho systemd-sleep:    ${YELLOW}[INATIVO]${NC}"
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
