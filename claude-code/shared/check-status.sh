#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# check-status.sh — Auditoria Geral do KDE Plasma 6 Wayland Suite
# Verifica teclado (ABNT2/US-intl), cedilha (Chrome/Orca/Electron), clipboard e gestos
# ==============================================================================

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
echo -e "${BOLD}[1/5] Sessão e Ambiente${NC}"
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
# 2. Higiene de Input Method (IM) & Compatibilidade com Ctrl+C
# -----------------------------------------------------------------------------
echo ""
echo -e "${BOLD}[2/5] Higiene de Input Method (Compatibilidade de Atalhos / Ctrl+C)${NC}"

if [ -f "$HOME/.config/environment.d/im.conf" ]; then
    echo -e "  • ${RED}[FALHA]${NC} ~/.config/environment.d/im.conf ainda existe (risco de quebra do Ctrl+C)."
else
    echo -e "  • ${GREEN}[OK]${NC} ~/.config/environment.d/im.conf ausente (limpo)."
fi

ACTIVE_IM_VARS="$(env | grep -E "^(GTK_IM_MODULE|QT_IM_MODULE|XMODIFIERS)=" || true)"
if [ -n "$ACTIVE_IM_VARS" ]; then
    echo -e "  • ${YELLOW}[AVISO]${NC} Variáveis IM legadas ativas na shell atual:\n    $ACTIVE_IM_VARS"
else
    echo -e "  • ${GREEN}[OK]${NC} Nenhuma variável nociva de IM_MODULE ativa na shell."
fi

# -----------------------------------------------------------------------------
# 3. Suporte a Cedilha no Layout US-intl (Chrome, Orca, Electron, GTK, Qt)
# -----------------------------------------------------------------------------
echo ""
echo -e "${BOLD}[3/5] Suporte a Cedilha no Layout US-intl (Chrome, Orca, Electron, GTK, Qt)${NC}"

# A. LC_CTYPE e XCOMPOSEFILE em environment.d
if [ -f "$HOME/.config/environment.d/cedilla.conf" ]; then
    if grep -q "LC_CTYPE=pt_BR.UTF-8" "$HOME/.config/environment.d/cedilla.conf" 2>/dev/null; then
        echo -e "  • ${GREEN}[OK]${NC} ~/.config/environment.d/cedilla.conf ativo (LC_CTYPE=pt_BR.UTF-8)."
    else
        echo -e "  • ${YELLOW}[AVISO]${NC} ~/.config/environment.d/cedilla.conf presente, mas sem LC_CTYPE=pt_BR.UTF-8."
    fi
else
    echo -e "  • ${YELLOW}[AVISO]${NC} ~/.config/environment.d/cedilla.conf ausente (execute './bin/kde-config fix-keyboard')."
fi

# B. Variáveis no systemd --user
if command -v systemctl >/dev/null 2>&1; then
    SYSTEMD_CTYPE="$(systemctl --user show-environment 2>/dev/null | grep '^LC_CTYPE=' || true)"
    if [ "$SYSTEMD_CTYPE" = "LC_CTYPE=pt_BR.UTF-8" ]; then
        echo -e "  • ${GREEN}[OK]${NC} systemd --user exportando $SYSTEMD_CTYPE."
    else
        echo -e "  • ${YELLOW}[AVISO]${NC} systemd --user sem LC_CTYPE=pt_BR.UTF-8 (${SYSTEMD_CTYPE:-não definido})."
    fi
fi

# C. ~/.XCompose
if [ -f "$HOME/.XCompose" ]; then
    if grep -q "dead_acute.*<c>.*ç" "$HOME/.XCompose" 2>/dev/null; then
        echo -e "  • ${GREEN}[OK]${NC} ~/.XCompose configurado (' + c -> ç)."
    else
        echo -e "  • ${YELLOW}[AVISO]${NC} ~/.XCompose presente mas sem regras completas para cedilha."
    fi
else
    echo -e "  • ${RED}[FALHA]${NC} ~/.XCompose não encontrado."
fi

# D. Flags de Wayland IME para Apps Chromium/Electron (Chrome, Orca, Code, etc.)
CHECK_APPS=("chrome-flags.conf:Google Chrome" "chromium-flags.conf:Chromium" "electron-flags.conf:Electron" "code-flags.conf:VS Code" "orca-flags.conf:Orca IDE")
FLAGS_OK=1
for item in "${CHECK_APPS[@]}"; do
    fname="${item%%:*}"
    dname="${item##*:}"
    fpath="$HOME/.config/$fname"
    if [ -f "$fpath" ] && grep -q -- "--enable-wayland-ime" "$fpath" 2>/dev/null; then
        echo -e "  • ${GREEN}[OK]${NC} $dname (~/.config/$fname): Wayland IME habilitado."
    else
        echo -e "  • ${YELLOW}[AVISO]${NC} $dname (~/.config/$fname): flags ausentes ou sem --enable-wayland-ime."
        FLAGS_OK=0
    fi
done

# E. Simulação em tempo real de composição via libxkbcommon
if command -v python3 >/dev/null 2>&1; then
    COMPOSE_TEST=$(python3 -c "
import ctypes, os
try:
    xkb = ctypes.CDLL('libxkbcommon.so.0')
    xkb.xkb_context_new.restype = ctypes.c_void_p
    xkb.xkb_context_new.argtypes = [ctypes.c_int]
    ctx = xkb.xkb_context_new(0)
    xkb.xkb_compose_table_new_from_locale.restype = ctypes.c_void_p
    xkb.xkb_compose_table_new_from_locale.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
    table = xkb.xkb_compose_table_new_from_locale(ctx, b'pt_BR.UTF-8', 0)
    xkb.xkb_compose_state_new.restype = ctypes.c_void_p
    xkb.xkb_compose_state_new.argtypes = [ctypes.c_void_p, ctypes.c_int]
    xkb.xkb_compose_state_feed.restype = ctypes.c_int
    xkb.xkb_compose_state_feed.argtypes = [ctypes.c_void_p, ctypes.c_uint32]
    xkb.xkb_compose_state_get_utf8.restype = ctypes.c_int
    xkb.xkb_compose_state_get_utf8.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t]
    state = xkb.xkb_compose_state_new(table, 0)
    xkb.xkb_compose_state_feed(state, 0xfe51) # dead_acute
    xkb.xkb_compose_state_feed(state, 0x0063) # c
    buf = ctypes.create_string_buffer(64)
    xkb.xkb_compose_state_get_utf8(state, buf, len(buf))
    res = buf.value.decode('utf-8')
    print('OK:' + res if res == 'ç' else 'FAIL:' + res)
except Exception as e:
    print('ERR:' + str(e))
" 2>/dev/null || echo "ERR:python")

    if [[ "$COMPOSE_TEST" == OK:* ]]; then
        echo -e "  • ${GREEN}[OK]${NC} Simulação do motor de composição: '<dead_acute> <c>' -> '${COMPOSE_TEST#OK:}' (cedilha validada)."
    elif [[ "$COMPOSE_TEST" == FAIL:* ]]; then
        echo -e "  • ${RED}[FALHA]${NC} Simulação do motor de composição gerou '${COMPOSE_TEST#FAIL:}' em vez de 'ç'."
    fi
fi

# -----------------------------------------------------------------------------
# 4. Configuração de Layouts KWin & Clipboard do Wayland
# -----------------------------------------------------------------------------
echo ""
echo -e "${BOLD}[4/5] Layouts no KWin & Clipboard do Wayland${NC}"

if [ -n "$QDBUS" ]; then
    LAYOUTS_LIST="$("$QDBUS" --literal org.kde.keyboard /Layouts org.kde.KeyboardLayouts.getLayoutsList 2>/dev/null || echo 'indisponivel')"
    ACTIVE_IDX="$("$QDBUS" org.kde.keyboard /Layouts org.kde.KeyboardLayouts.getLayout 2>/dev/null || echo 'indisponivel')"
    echo -e "  • ${GREEN}[OK]${NC} KWin D-Bus Layouts: $LAYOUTS_LIST"
    echo -e "  • ${GREEN}[OK]${NC} Layout Ativo no KWin (índice): $ACTIVE_IDX (0 = br abnt2, 1 = us alt-intl)"
else
    echo -e "  • ${YELLOW}[AVISO]${NC} Não foi possível consultar KWin Layouts via D-Bus."
fi

# Clipboard do Wayland (wl-clipboard vs xsel)
if command -v wl-copy >/dev/null 2>&1 && command -v wl-paste >/dev/null 2>&1; then
    echo -e "  • ${GREEN}[OK]${NC} wl-clipboard (wl-copy / wl-paste) instalado (Wayland nativo)."
else
    echo -e "  • ${RED}[FALHA]${NC} wl-clipboard NÃO instalado. Terminais e apps tentarão usar xsel (X11) e travarão o clipboard."
    echo -e "    ${YELLOW}Solução: sudo pacman -S wl-clipboard${NC}"
fi

HUNG_XSEL="$(pgrep -a xsel 2>/dev/null || true)"
if [ -n "$HUNG_XSEL" ]; then
    echo -e "  • ${RED}[FALHA]${NC} Processos xsel travados detectados (bloqueando Ctrl+Shift+V / colar):\n    $HUNG_XSEL"
    echo -e "    ${YELLOW}Execute: pkill -9 xsel${NC}"
else
    echo -e "  • ${GREEN}[OK]${NC} Nenhum processo xsel travado."
fi

# -----------------------------------------------------------------------------
# 5. Configuração de Touchpad Gestures
# -----------------------------------------------------------------------------
echo ""
echo -e "${BOLD}[5/5] Touchpad Gestures (libinput-gestures & KWin)${NC}"

if groups "$USER" | grep -qw "input"; then
    echo -e "  • ${GREEN}[OK]${NC} Usuário '$USER' pertence ao grupo 'input'."
else
    echo -e "  • ${RED}[FALHA]${NC} Usuário '$USER' NÃO pertence ao grupo 'input' (necessário: sudo usermod -aG input $USER)."
fi

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

if [ -n "$QDBUS" ]; then
    if "$QDBUS" org.kde.kglobalaccel /component/kwin org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1; then
        echo -e "  • ${GREEN}[OK]${NC} KGlobalAccel / KWin D-Bus respondendo para disparo de atalhos."
    else
        echo -e "  • ${YELLOW}[AVISO]${NC} KGlobalAccel / KWin D-Bus não respondeu ao ping."
    fi
fi

# -----------------------------------------------------------------------------
# Resumo Final
# -----------------------------------------------------------------------------
echo ""
echo -e "${BOLD}${BLUE}======================================================${NC}"
echo -e "${BOLD}${GREEN}✔ Verificação concluída.${NC}"
echo -e "${BOLD}${BLUE}======================================================${NC}"
