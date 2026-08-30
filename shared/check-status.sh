#!/usr/bin/env bash
set -euo pipefail

# Cores para saída
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${BLUE}======================================================${NC}"
echo -e "${BOLD}${BLUE}   KDE Plasma 6 Wayland — Verificação de Status Geral ${NC}"
echo -e "${BOLD}${BLUE}======================================================${NC}"
echo ""

# -----------------------------------------------------------------------------
# 1. Sessão e D-Bus
# -----------------------------------------------------------------------------
echo -e "${BOLD}[1/4] Sessão e Ambiente${NC}"
SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"
DESKTOP="${XDG_CURRENT_DESKTOP:-unknown}"
printf "  • Tipo de Sessão: %s\n" "$SESSION_TYPE"
printf "  • Ambiente Desktop: %s\n" "$DESKTOP"

if command -v qdbus6 >/dev/null 2>&1; then
    QDBUS="qdbus6"
elif command -v qdbus >/dev/null 2>&1; then
    QDBUS="qdbus"
elif [ -x /usr/lib/qt6/bin/qdbus ]; then
    QDBUS="/usr/lib/qt6/bin/qdbus"
else
    QDBUS=""
fi
printf "  • Cliente D-Bus: %s\n" "${QDBUS:-NÃO ENCONTRADO}"

# -----------------------------------------------------------------------------
# 2. Configuração de Teclado, Layouts e Atalhos
# -----------------------------------------------------------------------------
echo ""
echo -e "${BOLD}[2/4] Teclado, Layouts e Atalhos (Ctrl+C / Cedilha)${NC}"

# A. Variáveis de IM nocivas
if [ -f "$HOME/.config/environment.d/im.conf" ]; then
    echo -e "  • ${RED}[FALHA]${NC} ~/.config/environment.d/im.conf ainda existe."
else
    echo -e "  • ${GREEN}[OK]${NC} ~/.config/environment.d/im.conf ausente (limpo)."
fi

ACTIVE_IM_VARS="$(env | grep -E "^(GTK_IM_MODULE|QT_IM_MODULE|XMODIFIERS)=" || true)"
if [ -n "$ACTIVE_IM_VARS" ]; then
    echo -e "  • ${YELLOW}[AVISO]${NC} Variáveis IM ativas na shell atual (serão limpas ao reiniciar sessão):\n    $ACTIVE_IM_VARS"
else
    echo -e "  • ${GREEN}[OK]${NC} Nenhuma variável nociva de IM_MODULE ativa na shell."
fi

# B. ~/.XCompose
if [ -f "$HOME/.XCompose" ]; then
    if grep -q "dead_acute.*<c>.*ç" "$HOME/.XCompose" 2>/dev/null; then
        echo -e "  • ${GREEN}[OK]${NC} ~/.XCompose configurado corretamente (' + c -> ç)."
    else
        echo -e "  • ${YELLOW}[AVISO]${NC} ~/.XCompose existe mas não contém regra de cedilha esperada."
    fi
else
    echo -e "  • ${RED}[FALHA]${NC} ~/.XCompose não encontrado."
fi

# C. kxkbrc e KWin Wayland Layouts
if [ -n "$QDBUS" ]; then
    LAYOUTS_LIST="$("$QDBUS" --literal org.kde.keyboard /Layouts org.kde.KeyboardLayouts.getLayoutsList 2>/dev/null || echo 'indisponivel')"
    ACTIVE_IDX="$("$QDBUS" org.kde.keyboard /Layouts org.kde.KeyboardLayouts.getLayout 2>/dev/null || echo 'indisponivel')"
    echo -e "  • ${GREEN}[OK]${NC} KWin D-Bus Layouts: $LAYOUTS_LIST"
    echo -e "  • ${GREEN}[OK]${NC} Layout Ativo no KWin (índice): $ACTIVE_IDX"
else
    echo -e "  • ${YELLOW}[AVISO]${NC} Não foi possível consultar KWin Layouts via D-Bus."
fi

# -----------------------------------------------------------------------------
# 3. Configuração de Touchpad Gestures
# -----------------------------------------------------------------------------
echo ""
echo -e "${BOLD}[3/4] Touchpad Gestures (libinput-gestures & KWin)${NC}"

# A. Grupo input
if groups "$USER" | grep -qw "input"; then
    echo -e "  • ${GREEN}[OK]${NC} Usuário '$USER' pertence ao grupo 'input'."
else
    echo -e "  • ${RED}[FALHA]${NC} Usuário '$USER' NÃO pertence ao grupo 'input' (necessário: sudo usermod -aG input $USER)."
fi

# B. Daemon e Configuração
if command -v libinput-gestures >/dev/null 2>&1; then
    echo -e "  • ${GREEN}[OK]${NC} Binário libinput-gestures instalado."
    if command -v libinput-gestures-setup >/dev/null 2>&1; then
        SERVICE_STATUS="$(libinput-gestures-setup status 2>&1 || true)"
        echo -e "  • Status do Serviço:\n    $SERVICE_STATUS"
    fi
else
    echo -e "  • ${YELLOW}[AVISO]${NC} libinput-gestures não está instalado."
fi

if [ -f "$HOME/.config/libinput-gestures.conf" ]; then
    GESTURES_COUNT="$(grep -c -E "^gesture" "$HOME/.config/libinput-gestures.conf" 2>/dev/null || echo '0')"
    echo -e "  • ${GREEN}[OK]${NC} ~/.config/libinput-gestures.conf presente ($GESTURES_COUNT gestos mapeados)."
else
    echo -e "  • ${YELLOW}[AVISO]${NC} ~/.config/libinput-gestures.conf não encontrado."
fi

# C. D-Bus KWin Shortcuts
if [ -n "$QDBUS" ]; then
    if "$QDBUS" org.kde.kglobalaccel /component/kwin org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1; then
        echo -e "  • ${GREEN}[OK]${NC} KGlobalAccel / KWin D-Bus respondendo para disparo de atalhos."
    else
        echo -e "  • ${YELLOW}[AVISO]${NC} KGlobalAccel / KWin D-Bus não respondeu ao ping."
    fi
fi

# -----------------------------------------------------------------------------
# 4. Resumo Final
# -----------------------------------------------------------------------------
echo ""
echo -e "${BOLD}${BLUE}======================================================${NC}"
echo -e "${BOLD}${GREEN}✔ Verificação concluída.${NC}"
echo -e "${BOLD}${BLUE}======================================================${NC}"
