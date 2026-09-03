#!/usr/bin/env bash
set -uo pipefail

# ==============================================================================
# revert-battery.sh — Desfaz as correções aplicadas por configure-battery.sh
# usando o snapshot mais recente (ou um snapshot específico passado como $1).
# ==============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

BACKUP_ROOT="$HOME/.config/kde-config-backups"

if [ -n "${1:-}" ]; then
    BACKUP_DIR="$1"
else
    BACKUP_DIR="$(cat "$BACKUP_ROOT/.battery-latest" 2>/dev/null || true)"
fi

if [ -z "$BACKUP_DIR" ] || [ ! -d "$BACKUP_DIR" ]; then
    echo -e "${RED}Nenhum snapshot de bateria encontrado (esperado em $BACKUP_ROOT/.battery-latest ou como argumento).${NC}"
    exit 1
fi

MANIFEST="$BACKUP_DIR/manifest.env"
if [ ! -f "$MANIFEST" ]; then
    echo -e "${RED}Snapshot inválido: $MANIFEST não encontrado.${NC}"
    exit 1
fi

echo -e "${BOLD}${BLUE}======================================================${NC}"
echo -e "${BOLD}${BLUE}   Revertendo correções de bateria/energia            ${NC}"
echo -e "${BOLD}${BLUE}======================================================${NC}"
echo -e "Snapshot: $BACKUP_DIR"
echo ""

# shellcheck disable=SC1090
source "$MANIFEST"

if [ -n "${GPU_ENV_FILE:-}" ] && [ -n "${GPU_ENV_FILE_BACKUP:-}" ]; then
    echo -e "${BOLD}==> GPU primária do compositor${NC}"
    if [ -f "$GPU_ENV_FILE_BACKUP" ]; then
        cp -p "$GPU_ENV_FILE_BACKUP" "$GPU_ENV_FILE"
        echo -e "  ${GREEN}[OK]${NC} $GPU_ENV_FILE restaurado ao conteúdo original."
        echo -e "  ${BLUE}[INFO]${NC} Efeito só vale após sair da sessão (logout/login) ou reiniciar."
    else
        echo -e "  ${RED}[ERRO]${NC} Backup $GPU_ENV_FILE_BACKUP não encontrado — nada restaurado."
    fi
    echo ""
fi

if [ -n "${ASPM_ORIGINAL_POLICY:-}" ]; then
    echo -e "${BOLD}==> Política de PCIe ASPM${NC}"
    ASPM_FILE="/sys/module/pcie_aspm/parameters/policy"
    if [ -f "$ASPM_FILE" ]; then
        if sudo sh -c "echo '$ASPM_ORIGINAL_POLICY' > '$ASPM_FILE'" 2>/dev/null; then
            echo -e "  ${GREEN}[OK]${NC} Política ASPM restaurada para: $ASPM_ORIGINAL_POLICY"
        else
            echo -e "  ${RED}[ERRO]${NC} Falha ao restaurar $ASPM_FILE (precisa de sudo)."
        fi
    fi

    if [ -n "${ASPM_UNIT_FILE:-}" ] && [ -f "$ASPM_UNIT_FILE" ]; then
        sudo systemctl disable --now "$(basename "$ASPM_UNIT_FILE")" 2>/dev/null
        sudo rm -f "$ASPM_UNIT_FILE"
        sudo systemctl daemon-reload
        echo -e "  ${GREEN}[OK]${NC} Serviço $(basename "$ASPM_UNIT_FILE") desabilitado e removido."
    fi
    echo ""
fi

echo -e "${BOLD}${BLUE}======================================================${NC}"
echo -e "${BOLD}${GREEN}✔ Reversão concluída.${NC}"
echo -e "${BOLD}${BLUE}======================================================${NC}"
