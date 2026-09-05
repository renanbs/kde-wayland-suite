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

# shellcheck disable=SC1090
source "$MANIFEST"

SNAPSHOT_WHEN="$(basename "$BACKUP_DIR")"
if [ -n "${TIMESTAMP:-}" ]; then
    SNAPSHOT_DATE="${TIMESTAMP%%_*}"
    SNAPSHOT_TIME="$(echo "$TIMESTAMP" | cut -d_ -f2)"
    SNAPSHOT_WHEN="$(date -d "${SNAPSHOT_DATE:0:4}-${SNAPSHOT_DATE:4:2}-${SNAPSHOT_DATE:6:2} ${SNAPSHOT_TIME:0:2}:${SNAPSHOT_TIME:2:2}:${SNAPSHOT_TIME:4:2}" '+%d/%m/%Y às %H:%M:%S' 2>/dev/null || basename "$BACKUP_DIR")"
fi

echo -e "${BOLD}${BLUE}======================================================${NC}"
echo -e "${BOLD}${BLUE}   Revertendo correções de bateria/energia            ${NC}"
echo -e "${BOLD}${BLUE}======================================================${NC}"
echo -e "Snapshot: $BACKUP_DIR"
echo -e "Aplicado em: $SNAPSHOT_WHEN"
echo ""

REVERTED_ANY=0
SESSION_RESTART_NEEDED=0
declare -a SUMMARY=()

# -----------------------------------------------------------------------------
# 1. GPU primária (KWIN_DRM_DEVICES)
# -----------------------------------------------------------------------------
if [ -n "${GPU_ENV_FILE:-}" ] && [ -n "${GPU_ENV_FILE_BACKUP:-}" ]; then
    echo -e "${BOLD}==> GPU primária do compositor${NC}"
    if [ ! -f "$GPU_ENV_FILE_BACKUP" ]; then
        echo -e "  ${RED}[ERRO]${NC} Backup $GPU_ENV_FILE_BACKUP não encontrado — nada restaurado."
        SUMMARY+=("${RED}✘${NC} GPU primária: falhou (backup ausente)")
    elif [ ! -f "$GPU_ENV_FILE" ]; then
        echo -e "  ${RED}[ERRO]${NC} $GPU_ENV_FILE não existe mais — nada restaurado."
        SUMMARY+=("${RED}✘${NC} GPU primária: falhou (arquivo atual ausente)")
    elif diff -q "$GPU_ENV_FILE_BACKUP" "$GPU_ENV_FILE" >/dev/null 2>&1; then
        echo -e "  ${GREEN}[OK]${NC} $GPU_ENV_FILE já está igual ao original — nada a reverter aqui."
        SUMMARY+=("${GREEN}=${NC} GPU primária: já estava no estado original")
    else
        echo -e "  ${BLUE}[DIFF]${NC} Mudanças que serão desfeitas em $(basename "$GPU_ENV_FILE"):"
        diff -u "$GPU_ENV_FILE" "$GPU_ENV_FILE_BACKUP" | tail -n +3 | sed 's/^/    /'
        cp -p "$GPU_ENV_FILE_BACKUP" "$GPU_ENV_FILE"
        echo -e "  ${GREEN}[OK]${NC} $GPU_ENV_FILE restaurado ao conteúdo original."
        REVERTED_ANY=1
        SESSION_RESTART_NEEDED=1
        SUMMARY+=("${GREEN}✔${NC} GPU primária: revertida (ordem de KWIN_DRM_DEVICES restaurada)")
    fi
    echo ""
fi

# -----------------------------------------------------------------------------
# 2. PCIe ASPM
# -----------------------------------------------------------------------------
if [ -n "${ASPM_ORIGINAL_POLICY:-}" ]; then
    echo -e "${BOLD}==> Política de PCIe ASPM${NC}"
    ASPM_FILE="/sys/module/pcie_aspm/parameters/policy"
    if [ ! -f "$ASPM_FILE" ]; then
        echo -e "  ${YELLOW}[PULADO]${NC} $ASPM_FILE não existe mais neste kernel/BIOS."
        SUMMARY+=("${YELLOW}−${NC} PCIe ASPM: pulado (arquivo sysfs ausente)")
    else
        ASPM_CURRENT="$(grep -oP '(?<=\[)[a-z]+(?=\])' "$ASPM_FILE" 2>/dev/null)"
        if [ "$ASPM_CURRENT" = "$ASPM_ORIGINAL_POLICY" ]; then
            echo -e "  ${GREEN}[OK]${NC} Política já está em '$ASPM_ORIGINAL_POLICY' — nada a reverter aqui."
            SUMMARY+=("${GREEN}=${NC} PCIe ASPM: já estava no estado original ($ASPM_ORIGINAL_POLICY)")
        elif sudo sh -c "echo '$ASPM_ORIGINAL_POLICY' > '$ASPM_FILE'" 2>/dev/null; then
            echo -e "  ${GREEN}[OK]${NC} Política ASPM restaurada: $ASPM_CURRENT → $ASPM_ORIGINAL_POLICY"
            REVERTED_ANY=1
            SUMMARY+=("${GREEN}✔${NC} PCIe ASPM: revertida ($ASPM_CURRENT → $ASPM_ORIGINAL_POLICY)")
        else
            echo -e "  ${RED}[ERRO]${NC} Falha ao restaurar $ASPM_FILE (precisa de sudo)."
            SUMMARY+=("${RED}✘${NC} PCIe ASPM: falhou ao restaurar (sudo)")
        fi
    fi

    if [ -n "${ASPM_UNIT_FILE:-}" ] && [ -f "$ASPM_UNIT_FILE" ]; then
        sudo systemctl disable --now "$(basename "$ASPM_UNIT_FILE")" 2>/dev/null
        sudo rm -f "$ASPM_UNIT_FILE"
        sudo systemctl daemon-reload
        echo -e "  ${GREEN}[OK]${NC} Serviço $(basename "$ASPM_UNIT_FILE") desabilitado e removido (política não persiste mais no boot)."
        REVERTED_ANY=1
        SUMMARY+=("${GREEN}✔${NC} PCIe ASPM: serviço de persistência no boot removido")
    fi
    echo ""
fi

# -----------------------------------------------------------------------------
# 3. Runtime PM de dispositivos PCI
# -----------------------------------------------------------------------------
if [ -n "${PCI_RUNTIME_PM_BACKUP_FILE:-}" ]; then
    echo -e "${BOLD}==> Runtime PM de dispositivos PCI${NC}"
    if [ ! -f "$PCI_RUNTIME_PM_BACKUP_FILE" ]; then
        echo -e "  ${RED}[ERRO]${NC} Backup $PCI_RUNTIME_PM_BACKUP_FILE não encontrado — nada restaurado."
        SUMMARY+=("${RED}✘${NC} Runtime PM PCI: falhou (backup ausente)")
    else
        RESTORED=0
        FAILED=0
        while read -r addr val; do
            [ -z "$addr" ] && continue
            f="/sys/bus/pci/devices/$addr/power/control"
            [ -f "$f" ] || continue
            current="$(cat "$f" 2>/dev/null)"
            if [ "$current" = "$val" ]; then
                continue
            fi
            if sudo sh -c "echo '$val' > '$f'" 2>/dev/null; then
                RESTORED=$((RESTORED + 1))
            else
                FAILED=$((FAILED + 1))
            fi
        done < "$PCI_RUNTIME_PM_BACKUP_FILE"

        if [ "$RESTORED" -eq 0 ] && [ "$FAILED" -eq 0 ]; then
            echo -e "  ${GREEN}[OK]${NC} Todos os dispositivos já estavam iguais ao original — nada a reverter aqui."
            SUMMARY+=("${GREEN}=${NC} Runtime PM PCI: já estava no estado original")
        else
            [ "$RESTORED" -gt 0 ] && echo -e "  ${GREEN}[OK]${NC} $RESTORED dispositivo(s) restaurado(s) ao valor original de runtime PM."
            [ "$FAILED" -gt 0 ] && echo -e "  ${RED}[ERRO]${NC} Falha ao restaurar $FAILED dispositivo(s) (precisa de sudo)."
            if [ "$RESTORED" -gt 0 ]; then
                REVERTED_ANY=1
                SUMMARY+=("${GREEN}✔${NC} Runtime PM PCI: $RESTORED dispositivo(s) restaurado(s)")
            fi
            [ "$FAILED" -gt 0 ] && SUMMARY+=("${RED}✘${NC} Runtime PM PCI: $FAILED dispositivo(s) falharam")
        fi
    fi

    if [ -n "${PCI_RUNTIME_PM_UNIT_FILE:-}" ] && [ -f "$PCI_RUNTIME_PM_UNIT_FILE" ]; then
        sudo systemctl disable --now "$(basename "$PCI_RUNTIME_PM_UNIT_FILE")" 2>/dev/null
        sudo rm -f "$PCI_RUNTIME_PM_UNIT_FILE"
        sudo systemctl daemon-reload
        echo -e "  ${GREEN}[OK]${NC} Serviço $(basename "$PCI_RUNTIME_PM_UNIT_FILE") desabilitado e removido (não persiste mais no boot)."
        REVERTED_ANY=1
        SUMMARY+=("${GREEN}✔${NC} Runtime PM PCI: serviço de persistência no boot removido")
    fi
    echo ""
fi

if [ -z "${GPU_ENV_FILE:-}" ] && [ -z "${ASPM_ORIGINAL_POLICY:-}" ] && [ -z "${PCI_RUNTIME_PM_BACKUP_FILE:-}" ]; then
    echo -e "${YELLOW}Este snapshot não registra nenhuma correção revertível (manifest sem GPU_ENV_FILE, ASPM_ORIGINAL_POLICY ou PCI_RUNTIME_PM_BACKUP_FILE).${NC}"
    echo ""
fi

echo -e "${BOLD}${BLUE}======================================================${NC}"
echo -e "${BOLD}Resumo:${NC}"
if [ "${#SUMMARY[@]}" -eq 0 ]; then
    echo -e "  ${YELLOW}Nada para reverter neste snapshot.${NC}"
else
    for line in "${SUMMARY[@]}"; do
        echo -e "  $line"
    done
fi
echo ""
if [ "$REVERTED_ANY" = "1" ]; then
    echo -e "${BOLD}${GREEN}✔ Reversão concluída — algo foi restaurado.${NC}"
    [ "$SESSION_RESTART_NEEDED" = "1" ] && echo -e "  ${BLUE}[INFO]${NC} A GPU primária só volta ao normal após sair da sessão (logout/login) ou reiniciar."
else
    echo -e "${BOLD}${YELLOW}✔ Verificado — não havia nada para reverter (tudo já estava no estado original).${NC}"
fi
echo -e "${BOLD}${BLUE}======================================================${NC}"
