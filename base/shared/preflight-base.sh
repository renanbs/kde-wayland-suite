#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# preflight-base.sh — Diagnóstico Base de Ambiente para KDE Plasma 6 Wayland
# ==============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${BLUE}=== Diagnóstico e Pré-Voo Base para KDE Plasma ===${NC}"

# 1. Sessão e Ambiente Desktop
printf "SESSION_TYPE=%s\n" "${XDG_SESSION_TYPE:-unknown}"
printf "CURRENT_DESKTOP=%s\n" "${XDG_CURRENT_DESKTOP:-unknown}"

# 2. Distribuição
if [ -f /etc/os-release ]; then
  . /etc/os-release
  DISTRO="${ID:-unknown}"
  DISTRO_LIKE="${ID_LIKE:-}"
else
  DISTRO="unknown"
  DISTRO_LIKE=""
fi
printf "DISTRO=%s (LIKE=%s)\n" "$DISTRO" "$DISTRO_LIKE"
printf "KERNEL=%s\n" "$(uname -r)"

# 3. Versão do Plasma
if command -v kinfo >/dev/null 2>&1; then
  PLASMA_VER="$(kinfo 2>/dev/null | grep -i 'Plasma' | head -1 || true)"
elif command -v plasmashell >/dev/null 2>&1; then
  PLASMA_VER="$(plasmashell --version 2>&1 || true)"
else
  PLASMA_VER="unknown"
fi
printf "PLASMA_VERSION=%s\n" "$PLASMA_VER"

# 4. Detecção Dinâmica de qdbus / qdbus6
if command -v qdbus6 >/dev/null 2>&1; then
  QDBUS="$(command -v qdbus6)"
elif command -v qdbus >/dev/null 2>&1; then
  QDBUS="$(command -v qdbus)"
elif command -v qdbus-qt6 >/dev/null 2>&1; then
  QDBUS="$(command -v qdbus-qt6)"
elif [ -x /usr/lib/qt6/bin/qdbus ]; then
  QDBUS=/usr/lib/qt6/bin/qdbus
elif command -v qdbus-qt5 >/dev/null 2>&1; then
  QDBUS="$(command -v qdbus-qt5)"
else
  QDBUS=""
fi
printf "QDBUS_CLIENT=%s\n" "$QDBUS"

# 5. Grupo Input
if groups "$USER" | grep -qw "input"; then
  INPUT_GROUP_OK=true
else
  INPUT_GROUP_OK=false
fi
printf "INPUT_GROUP_OK=%s\n" "$INPUT_GROUP_OK"

# 6. Desktops Virtuais no KWin (Plasma 6)
if [ -n "$QDBUS" ]; then
  DESKTOPS_COUNT="$("$QDBUS" org.kde.KWin /VirtualDesktopManager org.kde.KWin.VirtualDesktopManager.count 2>/dev/null || echo 'unknown')"
  printf "KWIN_VIRTUAL_DESKTOPS=%s\n" "$DESKTOPS_COUNT"
fi

# 7. Fcitx5 — deve estar AUSENTE ou parado. Sob Wayland ele faz grab do
#    teclado e engole Ctrl+<tecla> (copiar/colar/desfazer) em Qt, GTK e
#    Electron por igual. Não é necessário para a cedilha: a tabela pt_BR do
#    sistema já mapeia <dead_acute> <c> -> "ç" nativamente.
if command -v fcitx5 >/dev/null 2>&1; then
  printf "FCITX5_INSTALLED=true\n"
  if pgrep -x fcitx5 >/dev/null 2>&1; then
    printf "FCITX5_RUNNING=true (ATENCAO: quebra Ctrl+<tecla>; corrija com './bin/kde-config fix-keyboard')\n"
  else
    printf "FCITX5_RUNNING=false (correto)\n"
  fi
else
  printf "FCITX5_INSTALLED=false\n"
fi

# 8. Locale de composição — é o que decide entre "ç" e "ć". Sem
#    LC_CTYPE=pt_BR.UTF-8 o libxkbcommon usa a tabela en_US, que mapeia
#    <dead_acute> <c> para "ć".
if [ "${LC_CTYPE:-}" = "pt_BR.UTF-8" ]; then
  printf "LC_CTYPE=%s\n" "$LC_CTYPE"
else
  printf "LC_CTYPE=%s (esperado pt_BR.UTF-8 para a cedilha; faca logout/login apos 'fix-keyboard')\n" "${LC_CTYPE:-<vazio>}"
fi
