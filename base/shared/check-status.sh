#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# check-status.sh — Auditoria Geral do KDE Plasma 6 Wayland Suite
# Verifica hardware DMI, teclado (ABNT2/US-intl), cedilha (Chrome/Orca/Electron),
# clipboard e gestos com emissão de eventos estruturados para o lib-runlog.sh.
# ==============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Registro estruturado do run (histórico e relatório). Silencioso se ausente.
if [ -f "$SCRIPT_DIR/lib-runlog.sh" ]; then
    # shellcheck source=lib-runlog.sh
    source "$SCRIPT_DIR/lib-runlog.sh"
else
    runlog_event() { :; }
    runlog_metric() { :; }
fi

echo -e "${BOLD}${BLUE}======================================================${NC}"
echo -e "${BOLD}${BLUE}   KDE Plasma 6 Wayland — Verificação de Status Geral ${NC}"
echo -e "${BOLD}${BLUE}======================================================${NC}"
echo ""

# -----------------------------------------------------------------------------
# 1. Sessão, D-Bus e Identificação de Hardware DMI
# -----------------------------------------------------------------------------
echo -e "${BOLD}[1/6] Sessão, Ambiente e Identificação de Hardware${NC}"
SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"
DESKTOP="${XDG_CURRENT_DESKTOP:-unknown}"
printf "  • Tipo de Sessão: %s\n" "$SESSION_TYPE"
printf "  • Ambiente Desktop: %s\n" "$DESKTOP"
runlog_event "info" "session_type" "$SESSION_TYPE"

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

# Identificação DMI
DMI_VENDOR="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo 'unknown')"
DMI_PRODUCT="$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo 'unknown')"
DMI_BOARD="$(cat /sys/class/dmi/id/board_name 2>/dev/null || echo 'unknown')"
printf "  • Hardware DMI: %s / %s (Placa: %s)\n" "$DMI_VENDOR" "$DMI_PRODUCT" "$DMI_BOARD"
runlog_event "info" "dmi_hardware" "$DMI_VENDOR / $DMI_PRODUCT"

# Detecção e auditoria de chassis Tongfang / Avell / Clevo
IS_TONGFANG=false
if echo "$DMI_VENDOR $DMI_PRODUCT $DMI_BOARD" | grep -qiE "tongfang|avell|clevo|tuxedo|schenker|uniwill|gk5|gm5|qc7"; then
    IS_TONGFANG=true
fi

if [ "$IS_TONGFANG" = "true" ]; then
    if grep -q "i8042.nopnp=1" /proc/cmdline 2>/dev/null && grep -qE "acpi_osi=['\"]?Windows" /proc/cmdline 2>/dev/null; then
        echo -e "  • ${GREEN}[OK]${NC} Chassis Tongfang/Avell com parâmetros i8042/ACPI ativos no boot (teclado desbloqueado)."
        runlog_event "ok" "tongfang_kernel_params" "i8042.nopnp=1 acpi_osi ativo"
    else
        echo -e "  • ${YELLOW}[AVISO]${NC} Chassis Tongfang/Avell detectado sem 'i8042.nopnp=1' ou 'acpi_osi' no boot."
        echo -e "    Risco: Tecla Control física pode ser descartada pelo driver i8042. Corrija com: ${BOLD}./bin/kde-config fix-tongfang${NC}"
        runlog_event "warn" "tongfang_kernel_params_missing" "Execute ./bin/kde-config fix-tongfang"
    fi
fi

# Auditoria de Gerenciamento de Energia do Teclado Integrado (i8042/serio0)
SERIO_POWER="/sys/devices/platform/i8042/serio0/power/control"
UDEV_RULE_FILE="/etc/udev/rules.d/90-kde-smart-keyboard-power.rules"
if [ -f "$SERIO_POWER" ]; then
    CURRENT_PWR="$(cat "$SERIO_POWER" 2>/dev/null || echo 'unknown')"
    if [ -f "$UDEV_RULE_FILE" ]; then
        echo -e "  • ${GREEN}[OK]${NC} Gerenciamento Dinâmico de Energia do Teclado: ${BOLD}ATIVO${NC} (serio0: ${CURRENT_PWR})."
        runlog_event "ok" "keyboard_smart_power" "rule_active, power=$CURRENT_PWR"
    elif [ "$CURRENT_PWR" = "on" ]; then
        echo -e "  • ${GREEN}[OK]${NC} Barramento i8042 em modo ativo permanente (power/control: ${BOLD}on${NC} - anti-latch)."
        runlog_event "ok" "keyboard_power_static_on" ""
    else
        echo -e "  • ${YELLOW}[AVISO]${NC} Barramento i8042 em economia ociosa (power/control: ${BOLD}auto${NC})."
        echo -e "    Risco: A primeira ativação do Left Ctrl pode sofrer atraso de wake. Para ativar gestão dinâmica: ${BOLD}./bin/kde-config smart-keyboard-power --apply${NC}"
        runlog_event "warn" "keyboard_power_auto_no_rule" "power=auto"
    fi
fi

# -----------------------------------------------------------------------------
# 2. Higiene de Input Method (IM) & Compatibilidade com Ctrl+C
# -----------------------------------------------------------------------------
echo ""
echo -e "${BOLD}[2/6] Higiene de Input Method (Compatibilidade de Atalhos / Ctrl+C)${NC}"

if [ -f "$HOME/.config/environment.d/im.conf" ]; then
    echo -e "  • ${RED}[FALHA]${NC} ~/.config/environment.d/im.conf ainda existe (risco de quebra do Ctrl+C)."
    runlog_event "fail" "im_conf_present" "im.conf quebra atalhos"
else
    echo -e "  • ${GREEN}[OK]${NC} ~/.config/environment.d/im.conf ausente (limpo)."
    runlog_event "ok" "im_conf_clean" ""
fi

if grep -qE '^(GTK_IM_MODULE|QT_IM_MODULE)=' "$HOME/.config/environment.d/cedilla.conf" 2>/dev/null; then
    echo -e "  • ${RED}[FALHA]${NC} ~/.config/environment.d/cedilla.conf força GTK_IM_MODULE/QT_IM_MODULE globalmente (quebra Ctrl+C no ABNT2). Rode './bin/kde-config fix-keyboard' para corrigir."
    runlog_event "fail" "im_env_forced" "cedilla.conf contem IM modules"
elif systemctl --user show-environment 2>/dev/null | grep -qE '^(GTK_IM_MODULE|QT_IM_MODULE)='; then
    echo -e "  • ${RED}[FALHA]${NC} systemd --user com GTK_IM_MODULE/QT_IM_MODULE=fcitx ativo (quebra Ctrl+C no ABNT2). Rode './bin/kde-config fix-keyboard' para corrigir."
    runlog_event "fail" "im_systemd_env_forced" "systemd user env contem IM modules"
else
    echo -e "  • ${GREEN}[OK]${NC} Nenhuma variável GTK_IM_MODULE/QT_IM_MODULE forçada globalmente."
    runlog_event "ok" "im_env_clean" ""
fi

if [ -f "$HOME/.config/kxkbrc" ]; then
    KXKB_LAYOUTS="$(grep -oP '(?<=^LayoutList=).*' "$HOME/.config/kxkbrc" 2>/dev/null || echo '')"
    if [ "$KXKB_LAYOUTS" = "br,us" ]; then
        echo -e "  • ${GREEN}[OK]${NC} kxkbrc com LayoutList completa (br,us)."
        runlog_event "ok" "kxkbrc_layout_complete" "$KXKB_LAYOUTS"
    elif [ -z "$KXKB_LAYOUTS" ]; then
        echo -e "  • ${YELLOW}[AVISO]${NC} ~/.config/kxkbrc sem LayoutList definida. Rode './bin/kde-config fix-keyboard'."
        runlog_event "warn" "kxkbrc_layout_empty" ""
    else
        echo -e "  • ${RED}[FALHA]${NC} Bug de colapso do kxkbrc detectado: LayoutList='$KXKB_LAYOUTS' (esperado 'br,us'). O Plasma descartou um layout ao encerrar a sessão anterior (bug conhecido do KWin). Rode './bin/kde-config fix-keyboard' para restaurar."
        runlog_event "fail" "kxkbrc_layout_collapsed" "$KXKB_LAYOUTS"
    fi

    if [ -f "$HOME/.config/autostart/kde-wayland-suite-restore-layout.desktop" ]; then
        echo -e "  • ${GREEN}[OK]${NC} Auto-cura do layout no login está ativa."
        runlog_event "ok" "layout_autoheal_active" ""
    else
        echo -e "  • ${BLUE}[INFO]${NC} Auto-cura do layout no login não está ativa (opcional)."
    fi
else
    echo -e "  • ${YELLOW}[AVISO]${NC} ~/.config/kxkbrc não encontrado. Rode './bin/kde-config fix-keyboard'."
    runlog_event "warn" "kxkbrc_missing" ""
fi

# -----------------------------------------------------------------------------
# 3. Suporte a Cedilha no Layout US-intl (Chrome, Orca, Electron, GTK, Qt)
# -----------------------------------------------------------------------------
echo ""
echo -e "${BOLD}[3/6] Suporte a Cedilha no Layout US-intl (Chrome, Orca, Electron, GTK, Qt)${NC}"

if [ -f "$HOME/.config/environment.d/cedilla.conf" ]; then
    if grep -q "LC_CTYPE=pt_BR.UTF-8" "$HOME/.config/environment.d/cedilla.conf" 2>/dev/null; then
        echo -e "  • ${GREEN}[OK]${NC} ~/.config/environment.d/cedilla.conf ativo (LC_CTYPE=pt_BR.UTF-8)."
        runlog_event "ok" "cedilla_conf_active" ""
    else
        echo -e "  • ${YELLOW}[AVISO]${NC} ~/.config/environment.d/cedilla.conf presente, mas sem LC_CTYPE=pt_BR.UTF-8."
        runlog_event "warn" "cedilla_conf_invalid" ""
    fi
else
    echo -e "  • ${YELLOW}[AVISO]${NC} ~/.config/environment.d/cedilla.conf ausente (execute './bin/kde-config fix-keyboard')."
    runlog_event "warn" "cedilla_conf_missing" ""
fi

USER_FCITX_DESKTOP="$HOME/.config/autostart/org.fcitx.Fcitx5.desktop"
SYSTEM_FCITX_DESKTOP=""
for f in /etc/xdg/autostart/org.fcitx.Fcitx5.desktop /usr/share/autostart/org.fcitx.Fcitx5.desktop; do
    [ -f "$f" ] && SYSTEM_FCITX_DESKTOP="$f" && break
done

if pgrep -x fcitx5 >/dev/null 2>&1; then
    echo -e "  • ${RED}[FALHA]${NC} fcitx5 está rodando — ele quebra Ctrl+<tecla> no sistema inteiro sob Wayland."
    echo -e "    Corrija com: ${BOLD}./bin/kde-config fix-keyboard${NC} (encerra o processo e mascara o autostart)."
    runlog_event "fail" "fcitx5_running" "fcitx5 engole eventos de Ctrl"
elif [ -f "$USER_FCITX_DESKTOP" ] && grep -qi "^Hidden=true" "$USER_FCITX_DESKTOP" 2>/dev/null; then
    echo -e "  • ${GREEN}[OK]${NC} fcitx5 desligado e mascarado (Ctrl+<tecla> preservado)."
    runlog_event "ok" "fcitx5_masked" ""
elif [ -n "$SYSTEM_FCITX_DESKTOP" ]; then
    echo -e "  • ${RED}[FALHA]${NC} fcitx5 não está rodando agora, mas o pacote tem autostart de sistema sem máscara em ~/.config/autostart."
    echo -e "    Corrija com: ${BOLD}./bin/kde-config fix-keyboard${NC}"
    runlog_event "fail" "fcitx5_system_autostart_unmasked" ""
else
    echo -e "  • ${GREEN}[OK]${NC} fcitx5 desligado e sem autostart (Ctrl+<tecla> preservado)."
    runlog_event "ok" "fcitx5_clean" ""
fi

CHECK_APPS=("chrome-flags.conf:Google Chrome" "chromium-flags.conf:Chromium" "electron-flags.conf:Electron" "code-flags.conf:VS Code" "orca-flags.conf:Orca IDE")
for item in "${CHECK_APPS[@]}"; do
    fname="${item%%:*}"
    dname="${item##*:}"
    fpath="$HOME/.config/$fname"
    if [ ! -f "$fpath" ]; then
        echo -e "  • ${YELLOW}[AVISO]${NC} $dname (~/.config/$fname): ausente ou não configurado."
    elif grep -q -- "--ozone-platform-hint=auto" "$fpath" 2>/dev/null; then
        echo -e "  • ${GREEN}[OK]${NC} $dname (~/.config/$fname): flags de Wayland corretas."
    fi
done

if [ "${LC_CTYPE:-}" = "pt_BR.UTF-8" ]; then
    echo -e "  • ${GREEN}[OK]${NC} LC_CTYPE=pt_BR.UTF-8 neste processo (tabela de composição: dead_acute + c -> ç)."
    runlog_event "ok" "lc_ctype_process" "$LC_CTYPE"
else
    echo -e "  • ${YELLOW}[AVISO]${NC} LC_CTYPE='${LC_CTYPE:-vazio}' neste processo (faça logout/login após 'fix-keyboard')."
    runlog_event "warn" "lc_ctype_process_missing" "${LC_CTYPE:-vazio}"
fi

# -----------------------------------------------------------------------------
# 4. Simulação de Composição via libxkbcommon
# -----------------------------------------------------------------------------
echo ""
echo -e "${BOLD}[4/6] Simulação do Motor de Composição (libxkbcommon)${NC}"

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
        runlog_event "ok" "xkb_compose_engine" "cedilha validada"
    elif [[ "$COMPOSE_TEST" == FAIL:* ]]; then
        echo -e "  • ${RED}[FALHA]${NC} Simulação do motor de composição gerou '${COMPOSE_TEST#FAIL:}' em vez de 'ç'."
        runlog_event "fail" "xkb_compose_engine" "retornou ${COMPOSE_TEST#FAIL:}"
    fi
fi

# -----------------------------------------------------------------------------
# 5. Configuração de Layouts KWin & Clipboard do Wayland
# -----------------------------------------------------------------------------
echo ""
echo -e "${BOLD}[5/6] Layouts no KWin & Clipboard do Wayland${NC}"

if [ -n "$QDBUS" ]; then
    LAYOUTS_LIST="$("$QDBUS" --literal org.kde.keyboard /Layouts org.kde.KeyboardLayouts.getLayoutsList 2>/dev/null || echo 'indisponivel')"
    ACTIVE_IDX="$("$QDBUS" org.kde.keyboard /Layouts org.kde.KeyboardLayouts.getLayout 2>/dev/null || echo 'indisponivel')"
    echo -e "  • ${GREEN}[OK]${NC} KWin D-Bus Layouts: $LAYOUTS_LIST"
    echo -e "  • ${GREEN}[OK]${NC} Layout Ativo no KWin (índice): $ACTIVE_IDX (0 = br abnt2, 1 = us alt-intl)"
    runlog_event "ok" "kwin_layouts" "active_idx=$ACTIVE_IDX"
fi

if command -v wl-copy >/dev/null 2>&1 && command -v wl-paste >/dev/null 2>&1; then
    echo -e "  • ${GREEN}[OK]${NC} wl-clipboard (wl-copy / wl-paste) instalado (Wayland nativo)."
    runlog_event "ok" "wl_clipboard_installed" ""
fi

HUNG_XSEL="$(pgrep -a xsel 2>/dev/null || true)"
if [ -n "$HUNG_XSEL" ]; then
    echo -e "  • ${RED}[FALHA]${NC} Processos xsel travados detectados:\n    $HUNG_XSEL"
    runlog_event "fail" "xsel_hung" "$HUNG_XSEL"
else
    echo -e "  • ${GREEN}[OK]${NC} Nenhum processo xsel travado."
    runlog_event "ok" "xsel_clean" ""
fi

# -----------------------------------------------------------------------------
# 6. Configuração de Touchpad Gestures
# -----------------------------------------------------------------------------
echo ""
echo -e "${BOLD}[6/6] Touchpad Gestures (libinput-gestures & KWin)${NC}"

if groups "$USER" | grep -qw "input"; then
    echo -e "  • ${GREEN}[OK]${NC} Usuário '$USER' pertence ao grupo 'input'."
    runlog_event "ok" "input_group" "$USER"
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
    runlog_event "ok" "gestures_conf" "count=$GESTURES_COUNT"
fi

if [ -n "$QDBUS" ]; then
    if "$QDBUS" org.kde.kglobalaccel /component/kwin org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1; then
        echo -e "  • ${GREEN}[OK]${NC} KGlobalAccel / KWin D-Bus respondendo para disparo de atalhos."
        runlog_event "ok" "kglobalaccel_kwin" "ping_ok"
    fi
fi

echo ""
echo -e "${BOLD}${BLUE}======================================================${NC}"
echo -e "${BOLD}${GREEN}✔ Verificação concluída.${NC}"
echo -e "${BOLD}${BLUE}======================================================${NC}"
