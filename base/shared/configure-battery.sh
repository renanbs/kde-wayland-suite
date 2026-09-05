#!/usr/bin/env bash
set -uo pipefail

# ==============================================================================
# configure-battery.sh — Aplica correções de bateria/energia decididas pelo
# usuário (via agente de IA + AskUserQuestion). Nunca decide sozinho o que
# aplicar: cada correção só roda se a variável de ambiente correspondente
# estiver setada. Sempre cria backup antes de mudar algo, para revert-battery.sh.
#
# Variáveis de ambiente:
#   BATTERY_FIX_GPU_PRIMARY=1        Reordena KWIN_DRM_DEVICES para a GPU do
#                                     painel interno (eDP) ficar primária.
#   BATTERY_FIX_PCIE_ASPM=1          Aplica política powersave de ASPM (sysfs,
#                                     efeito imediato, não sobrevive a reboot).
#   BATTERY_FIX_PCIE_ASPM_PERSIST=1  Junto com o acima, cria um serviço
#                                     systemd que reaplica a política a cada boot.
#   BATTERY_FIX_PCI_RUNTIME_PM=1     Move todo dispositivo PCI com power/control
#                                     != 'auto' para 'auto' (sysfs, efeito
#                                     imediato, não sobrevive a reboot).
#   BATTERY_FIX_PCI_RUNTIME_PM_PERSIST=1  Junto com o acima, cria um serviço
#                                     systemd que reaplica 'auto' a cada boot.
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

if [ "${BATTERY_FIX_GPU_PRIMARY:-0}" != "1" ] && [ "${BATTERY_FIX_PCIE_ASPM:-0}" != "1" ] && [ "${BATTERY_FIX_PCI_RUNTIME_PM:-0}" != "1" ]; then
    echo -e "${YELLOW}Nenhuma correção selecionada (BATTERY_FIX_GPU_PRIMARY / BATTERY_FIX_PCIE_ASPM / BATTERY_FIX_PCI_RUNTIME_PM ausentes). Nada a fazer.${NC}"
    echo "Rode './bin/kde-config battery-status' para diagnosticar antes."
    exit 0
fi

TIMESTAMP="$(date +%Y%m%d_%H%M%S)_$$"
BACKUP_ROOT="$HOME/.config/kde-config-backups"
BACKUP_DIR="$BACKUP_ROOT/battery_$TIMESTAMP"
if [ -e "$BACKUP_DIR" ]; then
    echo -e "${RED}Erro: $BACKUP_DIR já existe (colisão inesperada). Aborte e rode de novo.${NC}"
    exit 1
fi
mkdir -p "$BACKUP_DIR"
MANIFEST="$BACKUP_DIR/manifest.env"
: > "$MANIFEST"
echo "TIMESTAMP=$TIMESTAMP" >> "$MANIFEST"

echo -e "${BOLD}${BLUE}======================================================${NC}"
echo -e "${BOLD}${BLUE}   Aplicando correções de bateria/energia             ${NC}"
echo -e "${BOLD}${BLUE}======================================================${NC}"
echo -e "Backup desta execução: $BACKUP_DIR"
echo ""

APPLIED_ANY=0

# -----------------------------------------------------------------------------
# 1. GPU primária (KWIN_DRM_DEVICES)
# -----------------------------------------------------------------------------
if [ "${BATTERY_FIX_GPU_PRIMARY:-0}" = "1" ]; then
    echo -e "${BOLD}==> GPU primária do compositor${NC}"
    kwin_drm_locate

    if [ -z "$KWIN_DRM_VALUE" ]; then
        echo -e "  ${YELLOW}[PULADO]${NC} Nenhum KWIN_DRM_DEVICES customizado encontrado — nada a reordenar."
    else
        read -r EDP_CARD EDP_PCI <<< "$(find_edp_card_pci)"
        if [ -z "$EDP_CARD" ]; then
            echo -e "  ${RED}[ERRO]${NC} Não foi possível identificar a GPU do painel interno (eDP). Abortando esta correção."
        else
            mapfile -t ENTRIES < <(kwin_drm_split "$KWIN_DRM_VALUE")
            EDP_IDX=-1
            for i in "${!ENTRIES[@]}"; do
                if [ "$(pci_for_device_path "${ENTRIES[$i]}")" = "$EDP_PCI" ]; then
                    EDP_IDX=$i
                    break
                fi
            done

            if [ "$EDP_IDX" -lt 0 ]; then
                echo -e "  ${RED}[ERRO]${NC} A GPU do painel interno (PCI $EDP_PCI) não está na lista de KWIN_DRM_DEVICES atual. Abortando esta correção."
            else
                # Sempre faz backup, mesmo se já estiver correto (EDP_IDX=0) — garante
                # que "reverter" sempre tenha um snapshot válido do estado pré-execução.
                cp -p "$KWIN_ENV_FILE" "$BACKUP_DIR/$(basename "$KWIN_ENV_FILE").orig"
                echo "GPU_ENV_FILE=$KWIN_ENV_FILE" >> "$MANIFEST"
                echo "GPU_ENV_FILE_BACKUP=$BACKUP_DIR/$(basename "$KWIN_ENV_FILE").orig" >> "$MANIFEST"
            fi

            if [ "$EDP_IDX" -eq 0 ]; then
                echo -e "  ${GREEN}[OK]${NC} A GPU do painel interno já é a primeira da lista. Nada a fazer."
            elif [ "$EDP_IDX" -gt 0 ]; then
                NEW_ENTRIES=("${ENTRIES[$EDP_IDX]}")
                for i in "${!ENTRIES[@]}"; do
                    [ "$i" -eq "$EDP_IDX" ] && continue
                    NEW_ENTRIES+=("${ENTRIES[$i]}")
                done
                NEW_VALUE="$(printf '%s\n' "${NEW_ENTRIES[@]}" | kwin_drm_join)"

                sed -E -i "s#(KWIN_DRM_DEVICES=)\"[^\"]*\"#\\1\"${NEW_VALUE//\\/\\\\}\"#" "$KWIN_ENV_FILE"
                echo -e "  ${GREEN}[OK]${NC} $KWIN_ENV_FILE atualizado — GPU do painel interno agora é primária."
                echo -e "  ${BLUE}[INFO]${NC} Efeito só vale após sair da sessão (logout/login) ou reiniciar."
                APPLIED_ANY=1
            fi
        fi
    fi
    echo ""
fi

# -----------------------------------------------------------------------------
# 2. PCIe ASPM
# -----------------------------------------------------------------------------
if [ "${BATTERY_FIX_PCIE_ASPM:-0}" = "1" ]; then
    echo -e "${BOLD}==> Política de PCIe ASPM${NC}"
    ASPM_FILE="/sys/module/pcie_aspm/parameters/policy"
    if [ ! -f "$ASPM_FILE" ]; then
        echo -e "  ${YELLOW}[PULADO]${NC} $ASPM_FILE não existe neste kernel/BIOS."
    else
        ASPM_CURRENT="$(grep -oP '(?<=\[)[a-z]+(?=\])' "$ASPM_FILE" 2>/dev/null)"
        echo "ASPM_ORIGINAL_POLICY=$ASPM_CURRENT" >> "$MANIFEST"

        if [ "$ASPM_CURRENT" = "powersave" ] || [ "$ASPM_CURRENT" = "powersupersave" ]; then
            echo -e "  ${GREEN}[OK]${NC} Já em modo econômico ($ASPM_CURRENT). Nada a fazer."
        else
            if sudo sh -c "echo powersave > '$ASPM_FILE'" 2>/dev/null; then
                echo -e "  ${GREEN}[OK]${NC} Política ASPM aplicada: powersave (efeito imediato)."
                APPLIED_ANY=1
            else
                echo -e "  ${RED}[ERRO]${NC} Falha ao escrever em $ASPM_FILE (precisa de sudo)."
            fi

            if [ "${BATTERY_FIX_PCIE_ASPM_PERSIST:-0}" = "1" ]; then
                UNIT_FILE="/etc/systemd/system/kde-suite-pcie-aspm.service"
                echo "ASPM_UNIT_FILE=$UNIT_FILE" >> "$MANIFEST"
                sudo tee "$UNIT_FILE" > /dev/null << 'EOF'
[Unit]
Description=kde-wayland-suite: aplica politica PCIe ASPM powersave no boot
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo powersave > /sys/module/pcie_aspm/parameters/policy'

[Install]
WantedBy=multi-user.target
EOF
                sudo systemctl daemon-reload
                sudo systemctl enable --now kde-suite-pcie-aspm.service
                echo -e "  ${GREEN}[OK]${NC} Serviço kde-suite-pcie-aspm.service criado e habilitado — política persiste após reboot."
            else
                echo -e "  ${BLUE}[INFO]${NC} Mudança não persiste após reboot (BATTERY_FIX_PCIE_ASPM_PERSIST não foi setada)."
            fi
        fi
    fi
    echo ""
fi

# -----------------------------------------------------------------------------
# 3. Runtime PM de dispositivos PCI
# -----------------------------------------------------------------------------
if [ "${BATTERY_FIX_PCI_RUNTIME_PM:-0}" = "1" ]; then
    echo -e "${BOLD}==> Runtime PM de dispositivos PCI${NC}"
    PCI_BACKUP_FILE="$BACKUP_DIR/pci-runtime-pm.orig"
    : > "$PCI_BACKUP_FILE"
    CHANGED=0
    for f in /sys/bus/pci/devices/*/power/control; do
        [ -f "$f" ] || continue
        addr="$(basename "$(dirname "$(dirname "$f")")")"
        val="$(cat "$f" 2>/dev/null)"
        echo "$addr $val" >> "$PCI_BACKUP_FILE"
        if [ "$val" != "auto" ]; then
            if sudo sh -c "echo auto > '$f'" 2>/dev/null; then
                CHANGED=$((CHANGED + 1))
            fi
        fi
    done
    echo "PCI_RUNTIME_PM_BACKUP_FILE=$PCI_BACKUP_FILE" >> "$MANIFEST"

    if [ "$CHANGED" -gt 0 ]; then
        echo -e "  ${GREEN}[OK]${NC} $CHANGED dispositivo(s) PCI movidos para runtime PM 'auto' (efeito imediato)."
        APPLIED_ANY=1
    else
        echo -e "  ${GREEN}[OK]${NC} Já estava tudo em 'auto'. Nada a fazer."
    fi

    if [ "${BATTERY_FIX_PCI_RUNTIME_PM_PERSIST:-0}" = "1" ]; then
        UNIT_FILE="/etc/systemd/system/kde-suite-pci-runtime-pm.service"
        echo "PCI_RUNTIME_PM_UNIT_FILE=$UNIT_FILE" >> "$MANIFEST"
        sudo tee "$UNIT_FILE" > /dev/null << 'EOF'
[Unit]
Description=kde-wayland-suite: aplica runtime PM 'auto' em todos os dispositivos PCI no boot
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'for f in /sys/bus/pci/devices/*/power/control; do echo auto > "$f"; done'

[Install]
WantedBy=multi-user.target
EOF
        sudo systemctl daemon-reload
        sudo systemctl enable --now kde-suite-pci-runtime-pm.service
        echo -e "  ${GREEN}[OK]${NC} Serviço kde-suite-pci-runtime-pm.service criado e habilitado — política persiste após reboot."
    else
        echo -e "  ${BLUE}[INFO]${NC} Mudança não persiste após reboot (BATTERY_FIX_PCI_RUNTIME_PM_PERSIST não foi setada)."
    fi
    echo ""
fi

echo "battery-latest" > /dev/null # noop, apenas ponto de leitura visual
echo "$BACKUP_DIR" > "$BACKUP_ROOT/.battery-latest"

echo -e "${BOLD}${BLUE}======================================================${NC}"
if [ "$APPLIED_ANY" = "1" ]; then
    echo -e "${BOLD}${GREEN}✔ Correções aplicadas. Snapshot de reversão salvo em:${NC}"
    echo -e "    $BACKUP_DIR"
    echo -e "  Para reverter: ${BOLD}./bin/kde-config battery-revert${NC}"
else
    echo -e "${BOLD}${YELLOW}Nenhuma mudança de fato aplicada (tudo já estava correto ou foi pulado).${NC}"
fi
echo -e "${BOLD}${BLUE}======================================================${NC}"
