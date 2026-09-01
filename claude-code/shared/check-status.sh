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

# GTK_IM_MODULE/QT_IM_MODULE=fcitx globais quebram Ctrl+C em apps Qt/GTK no ABNT2
# (Chrome/Orca/Electron não precisam disso — falam com o Fcitx5 via Wayland IME).
if grep -qE '^(GTK_IM_MODULE|QT_IM_MODULE)=' "$HOME/.config/environment.d/cedilla.conf" 2>/dev/null; then
    echo -e "  • ${RED}[FALHA]${NC} ~/.config/environment.d/cedilla.conf força GTK_IM_MODULE/QT_IM_MODULE globalmente (quebra Ctrl+C no ABNT2). Rode './bin/kde-config fix-keyboard' para corrigir."
elif systemctl --user show-environment 2>/dev/null | grep -qE '^(GTK_IM_MODULE|QT_IM_MODULE)='; then
    echo -e "  • ${RED}[FALHA]${NC} systemd --user com GTK_IM_MODULE/QT_IM_MODULE=fcitx ativo (quebra Ctrl+C no ABNT2). Rode './bin/kde-config fix-keyboard' para corrigir."
else
    echo -e "  • ${GREEN}[OK]${NC} Nenhuma variável GTK_IM_MODULE/QT_IM_MODULE forçada globalmente."
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

# B. Status do Fcitx5 (Wayland IME)
if command -v fcitx5 >/dev/null 2>&1; then
    FCITX_VER="$(fcitx5 --version 2>&1 | head -n 1 || echo 'instalado')"
    if pgrep -x fcitx5 >/dev/null 2>&1; then
        echo -e "  • ${GREEN}[OK]${NC} Fcitx5 ($FCITX_VER): daemon ativo em background (Wayland IME pronto)."
    else
        echo -e "  • ${YELLOW}[AVISO]${NC} Fcitx5 instalado mas daemon não está rodando (inicie com 'fcitx5 -d')."
    fi
else
    echo -e "  • ${YELLOW}[INFO]${NC} Fcitx5 não instalado. No Wayland nativo, Chrome/Orca necessitam de 'fcitx5-im' para mapear '${BOLD}'+c${NC}${YELLOW}' -> '${BOLD}ç${NC}${YELLOW}'."
    echo -e "    ${BOLD}Instalação:${NC} sudo pacman -S --needed fcitx5-im fcitx5-gtk fcitx5-qt fcitx5-configtool"
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

# D. Flags para Apps Chromium/Electron (Chrome, Orca, Code, etc.)
CHECK_APPS=("chrome-flags.conf:Google Chrome" "chromium-flags.conf:Chromium" "electron-flags.conf:Electron" "code-flags.conf:VS Code" "orca-flags.conf:Orca IDE")
for item in "${CHECK_APPS[@]}"; do
    fname="${item%%:*}"
    dname="${item##*:}"
    fpath="$HOME/.config/$fname"
    if [ -f "$fpath" ] && grep -qE -- "(--enable-wayland-ime|--ozone-platform-hint=auto)" "$fpath" 2>/dev/null; then
        echo -e "  • ${GREEN}[OK]${NC} $dname (~/.config/$fname): flags de Wayland IME ativas."
    else
        echo -e "  • ${YELLOW}[AVISO]${NC} $dname (~/.config/$fname): flags ausentes ou não configuradas."
    fi
done

# E. Simulação em tempo real de composição via libxkbcommon
if command -v python3 >/dev/null 2>&1; then
    COMPOSE_TEST=$(python3 -c "
import ctypes
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
fi

if command -v wl-copy >/dev/null 2>&1 && command -v wl-paste >/dev/null 2>&1; then
    echo -e "  • ${GREEN}[OK]${NC} wl-clipboard (wl-copy / wl-paste) instalado (Wayland nativo)."
fi

HUNG_XSEL="$(pgrep -a xsel 2>/dev/null || true)"
if [ -n "$HUNG_XSEL" ]; then
    echo -e "  • ${RED}[FALHA]${NC} Processos xsel travados detectados:\n    $HUNG_XSEL"
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
fi

if command -v libinput-gestures >/dev/null 2>&1; then
    echo -e "  • ${GREEN}[OK]${NC} Binário libinput-gestures instalado."
    if command -v libinput-gestures-setup >/dev/null 2>&1; then
        SERVICE_STATUS="$(libinput-gestures-setup status 2>&1 || true)"
        echo -e "  • Status do Serviço:\n    $SERVICE_STATUS"
    fi
fi

if [ -f "$HOME/.config/libinput-gestures.conf" ]; then
    GESTURES_COUNT="$(grep -c -E "^gesture" "$HOME/.config/libinput-gestures.conf" 2>/dev/null || echo '0')"
    echo -e "  • ${GREEN}[OK]${NC} ~/.config/libinput-gestures.conf presente ($GESTURES_COUNT gestos mapeados)."
fi

if [ -n "$QDBUS" ]; then
    if "$QDBUS" org.kde.kglobalaccel /component/kwin org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1; then
        echo -e "  • ${GREEN}[OK]${NC} KGlobalAccel / KWin D-Bus respondendo para disparo de atalhos."
    fi
fi

echo ""
echo -e "${BOLD}${BLUE}======================================================${NC}"
echo -e "${BOLD}${GREEN}✔ Verificação concluída.${NC}"
echo -e "${BOLD}${BLUE}======================================================${NC}"
