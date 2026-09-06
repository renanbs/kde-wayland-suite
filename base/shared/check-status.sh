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

# Bug conhecido do KWin/Plasma: ao encerrar a sessão, o Plasma pode regravar
# kxkbrc mantendo só o layout ativo no momento do logout, descartando o
# resto da LayoutList (log típico: "kwin_wayland: XKB: More layouts than
# variants"). Detecta o colapso comparando com o estado esperado (br,us).
if [ -f "$HOME/.config/kxkbrc" ]; then
    KXKB_LAYOUTS="$(grep -oP '(?<=^LayoutList=).*' "$HOME/.config/kxkbrc" 2>/dev/null || echo '')"
    if [ "$KXKB_LAYOUTS" = "br,us" ]; then
        echo -e "  • ${GREEN}[OK]${NC} kxkbrc com LayoutList completa (br,us)."
    elif [ -z "$KXKB_LAYOUTS" ]; then
        echo -e "  • ${YELLOW}[AVISO]${NC} ~/.config/kxkbrc sem LayoutList definida. Rode './bin/kde-config fix-keyboard'."
    else
        echo -e "  • ${RED}[FALHA]${NC} Bug de colapso do kxkbrc detectado: LayoutList='$KXKB_LAYOUTS' (esperado 'br,us'). O Plasma descartou um layout ao encerrar a sessão anterior (bug conhecido do KWin, fora do controle desta suite). Rode './bin/kde-config fix-keyboard' para restaurar; para evitar que aconteça de novo a cada reboot, habilite a auto-cura com 'KDE_SUITE_LAYOUT_AUTOHEAL=1 ./bin/kde-config fix-keyboard'."
    fi

    if [ -f "$HOME/.config/autostart/kde-wayland-suite-restore-layout.desktop" ]; then
        echo -e "  • ${GREEN}[OK]${NC} Auto-cura do layout no login está ativa."
    else
        echo -e "  • ${BLUE}[INFO]${NC} Auto-cura do layout no login não está ativa (opcional; protege contra o bug de colapso do kxkbrc acima)."
    fi
else
    echo -e "  • ${YELLOW}[AVISO]${NC} ~/.config/kxkbrc não encontrado. Rode './bin/kde-config fix-keyboard'."
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

# B. Fcitx5 — deve estar DESLIGADO: sob Wayland ele faz grab do teclado e
#    engole Ctrl+<tecla> (copiar/colar/desfazer) em Qt, GTK e Electron.
#    A cedilha não precisa dele (a tabela pt_BR do sistema já cobre).
if pgrep -x fcitx5 >/dev/null 2>&1; then
    echo -e "  • ${RED}[FALHA]${NC} fcitx5 está rodando — ele quebra Ctrl+<tecla> no sistema inteiro sob Wayland."
    echo -e "    Corrija com: ${BOLD}./bin/kde-config fix-keyboard${NC} (encerra o processo e remove o autostart)."
elif [ -f "$HOME/.config/autostart/org.fcitx.Fcitx5.desktop" ]; then
    echo -e "  • ${YELLOW}[AVISO]${NC} fcitx5 não está rodando, mas o autostart existe — ele volta no próximo login e quebrará o Ctrl+<tecla>."
    echo -e "    Corrija com: ${BOLD}./bin/kde-config fix-keyboard${NC}"
else
    echo -e "  • ${GREEN}[OK]${NC} fcitx5 desligado e sem autostart (Ctrl+<tecla> preservado)."
fi

# C. ~/.XCompose — não é mais usado. As regras que a suite escrevia eram
#    duplicatas exatas da tabela pt_BR e o libxkbcommon as descartava.
if [ -f "$HOME/.XCompose" ] && grep -q "Overrides explícitos para garantir cedilha" "$HOME/.XCompose" 2>/dev/null; then
    echo -e "  • ${YELLOW}[AVISO]${NC} ~/.XCompose gerado por versões antigas desta suite ainda presente (redundante). './bin/kde-config fix-keyboard' remove com backup."
elif [ -f "$HOME/.XCompose" ]; then
    echo -e "  • ${BLUE}[INFO]${NC} ~/.XCompose customizado presente (não é necessário para cedilha; a tabela pt_BR já cobre)."
else
    echo -e "  • ${GREEN}[OK]${NC} Sem ~/.XCompose — cedilha vem da tabela pt_BR do sistema via LC_CTYPE."
fi

# D. Flags para Apps Chromium/Electron (Chrome, Orca, Code, etc.)
#    --enable-wayland-ime é indesejada: só serve para falar com um input
#    method, que esta suite não usa mais.
CHECK_APPS=("chrome-flags.conf:Google Chrome" "chromium-flags.conf:Chromium" "electron-flags.conf:Electron" "code-flags.conf:VS Code" "orca-flags.conf:Orca IDE")
for item in "${CHECK_APPS[@]}"; do
    fname="${item%%:*}"
    dname="${item##*:}"
    fpath="$HOME/.config/$fname"
    if [ ! -f "$fpath" ]; then
        echo -e "  • ${YELLOW}[AVISO]${NC} $dname (~/.config/$fname): ausente ou não configurado."
    elif grep -q -- "--enable-wayland-ime" "$fpath" 2>/dev/null; then
        echo -e "  • ${YELLOW}[AVISO]${NC} $dname (~/.config/$fname): contém --enable-wayland-ime (resquício da abordagem com IME). Rode './bin/kde-config fix-keyboard'."
    elif grep -q -- "--ozone-platform-hint=auto" "$fpath" 2>/dev/null; then
        echo -e "  • ${GREEN}[OK]${NC} $dname (~/.config/$fname): flags de Wayland corretas."
    else
        echo -e "  • ${YELLOW}[AVISO]${NC} $dname (~/.config/$fname): sem --ozone-platform-hint=auto."
    fi
done

# D2. LC_CTYPE do processo — é o que decide se a composição dá "ç" ou "ć"
if [ "${LC_CTYPE:-}" = "pt_BR.UTF-8" ]; then
    echo -e "  • ${GREEN}[OK]${NC} LC_CTYPE=pt_BR.UTF-8 neste processo (tabela de composição correta: dead_acute + c -> ç)."
else
    echo -e "  • ${YELLOW}[AVISO]${NC} LC_CTYPE='${LC_CTYPE:-vazio}' neste processo — com a tabela en_US, dead_acute + c produz 'ć' em vez de 'ç'."
    echo -e "    Apps iniciados antes do último 'fix-keyboard' mantêm o ambiente antigo; faça logout/login."
fi

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
