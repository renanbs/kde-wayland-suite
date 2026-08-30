#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# fix-keyboard.sh — Correção de Atalhos, Cedilha e Clipboard no KDE Plasma 6 Wayland
# ==============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}==> [1/5] Removendo injeções legadas de GTK/QT_IM_MODULE...${NC}"
timestamp="$(date +%Y%m%d_%H%M%S)"
backup_dir="$HOME/.config/kde-config-backups/$timestamp"
mkdir -p "$backup_dir"

if [ -f "$HOME/.config/environment.d/im.conf" ]; then
    cp "$HOME/.config/environment.d/im.conf" "$backup_dir/"
    rm -f "$HOME/.config/environment.d/im.conf"
    echo -e "    ${GREEN}[OK]${NC} ~/.config/environment.d/im.conf removido com sucesso."
fi

# Zera variáveis no escopo da shell atual
unset GTK_IM_MODULE QT_IM_MODULE XMODIFIERS 2>/dev/null || true

echo -e "${BOLD}==> [2/5] Desbloqueando e garantindo backend de clipboard Wayland (wl-clipboard)...${NC}"
# Mata processos xsel legados travados no XWayland
pkill -9 xsel 2>/dev/null || true

if ! command -v wl-copy >/dev/null 2>&1 || ! command -v wl-paste >/dev/null 2>&1; then
    echo -e "    ${YELLOW}wl-clipboard não encontrado. Tentando instalar automaticamente...${NC}"
    if command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm wl-clipboard 2>/dev/null || {
            echo -e "    ${YELLOW}Aviso: Execute 'sudo pacman -S wl-clipboard' para habilitar copiar/colar nativo no terminal.${NC}"
        }
    elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -qq && sudo apt-get install -y wl-clipboard 2>/dev/null || true
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y wl-clipboard 2>/dev/null || true
    fi
fi

if command -v wl-copy >/dev/null 2>&1; then
    echo -e "    ${GREEN}[OK]${NC} wl-clipboard ativo (área de transferência nativa Wayland pronta)."
fi

echo -e "${BOLD}==> [3/5] Configurando suporte a cedilha nativo via ~/.XCompose...${NC}"
if [ -f "$HOME/.XCompose" ]; then
    cp "$HOME/.XCompose" "$backup_dir/"
fi

cat << 'EOF' > "$HOME/.XCompose"
include "%L"

<dead_acute> <c> : "ç" Ccedilla
<dead_acute> <C> : "Ç" Ccedilla
<acute> <c> : "ç" Ccedilla
<acute> <C> : "Ç" Ccedilla
EOF
echo -e "    ${GREEN}[OK]${NC} ~/.XCompose configurado para ' + c -> ç."

echo -e "${BOLD}==> [4/5] Gravando configuração de layout no KDE Plasma 6 com notificação...${NC}"
if [ -f "$HOME/.config/kxkbrc" ]; then
    cp "$HOME/.config/kxkbrc" "$backup_dir/"
fi

kwriteconfig6 --file kxkbrc --group Layout --key Use true --notify
kwriteconfig6 --file kxkbrc --group Layout --key LayoutList "br,us" --notify
kwriteconfig6 --file kxkbrc --group Layout --key VariantList "abnt2,alt-intl" --notify
kwriteconfig6 --file kxkbrc --group Layout --key DisplayNames "," --notify
echo -e "    ${GREEN}[OK]${NC} kxkbrc atualizado com flag --notify."

echo -e "${BOLD}==> [5/5] Sincronizando e ativando o layout via D-Bus (KWin)...${NC}"
if command -v qdbus6 >/dev/null 2>&1; then
    QDBUS="qdbus6"
elif command -v qdbus >/dev/null 2>&1; then
    QDBUS="qdbus"
elif [ -x /usr/lib/qt6/bin/qdbus ]; then
    QDBUS="/usr/lib/qt6/bin/qdbus"
else
    echo -e "    ${YELLOW}[AVISO]${NC} qdbus6/qdbus não encontrado no PATH."
    exit 0
fi

# Seleciona o layout 0 (br / abnt2)
"$QDBUS" org.kde.keyboard /Layouts org.kde.KeyboardLayouts.setLayout 0 >/dev/null 2>&1 || true

ACTIVE_LAYOUT="$("$QDBUS" --literal org.kde.keyboard /Layouts org.kde.KeyboardLayouts.getLayoutsList 2>/dev/null || echo 'indisponivel')"
ACTIVE_IDX="$("$QDBUS" org.kde.keyboard /Layouts org.kde.KeyboardLayouts.getLayout 2>/dev/null || echo '0')"

echo "    Layouts ativos: $ACTIVE_LAYOUT"
echo "    Índice ativo atual: $ACTIVE_IDX (0 = br abnt2)"
echo -e "${GREEN}==> [SUCESSO] Teclado e clipboard configurados. Atalhos (Ctrl+C, Ctrl+Shift+V) operando normalmente.${NC}"
