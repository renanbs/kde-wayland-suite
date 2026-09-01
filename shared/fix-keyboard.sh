#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# fix-keyboard.sh — Correção de Atalhos, Cedilha e Clipboard no KDE Plasma 6 Wayland
# Garante ' + c -> ç no layout US-intl (Chrome, Orca, Electron, GTK, Qt) e Ctrl+C no ABNT2
# ==============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${BLUE}==> [1/6] Removendo injeções legadas de IM e limpando ambiente...${NC}"
timestamp="$(date +%Y%m%d_%H%M%S)"
backup_dir="$HOME/.config/kde-config-backups/$timestamp"
mkdir -p "$backup_dir"

# Função auxiliar para backup seguro
backup_if_exists() {
    local file="$1"
    if [ -f "$file" ]; then
        local rel_path="${file#"$HOME"/}"
        mkdir -p "$backup_dir/$(dirname "$rel_path")"
        cp -p "$file" "$backup_dir/$rel_path"
    fi
}

# 1. Limpeza de im.conf legado que quebrava Ctrl+C
if [ -f "$HOME/.config/environment.d/im.conf" ]; then
    backup_if_exists "$HOME/.config/environment.d/im.conf"
    rm -f "$HOME/.config/environment.d/im.conf"
    echo -e "    ${GREEN}[OK]${NC} ~/.config/environment.d/im.conf removido com sucesso."
fi

# Zera variáveis nocivas legadas
unset GTK_IM_MODULE QT_IM_MODULE XMODIFIERS 2>/dev/null || true

echo -e "${BOLD}${BLUE}==> [2/6] Configurando ambiente de Input Method e Locale (Cedilha)...${NC}"
mkdir -p "$HOME/.config/environment.d"
backup_if_exists "$HOME/.config/environment.d/cedilla.conf"

# Verifica se o fcitx5 está instalado
HAS_FCITX5=0
if command -v fcitx5 >/dev/null 2>&1; then
    HAS_FCITX5=1
fi

if [ "$HAS_FCITX5" -eq 1 ]; then
    echo -e "    ${GREEN}[OK]${NC} Fcitx5 detectado! Configurando integração completa de Wayland IME..."
    # GTK_IM_MODULE/QT_IM_MODULE=fcitx NÃO são setados globalmente aqui: isso
    # forçaria TODO app Qt/GTK (Konsole, Dolphin, Kate...) a passar pelo Fcitx5,
    # o que quebra Ctrl+C no ABNT2. Chrome/Orca/Electron falam com o Fcitx5
    # diretamente via protocolo Wayland (--enable-wayland-ime nos *-flags.conf),
    # sem precisar dessas variáveis.
    cat << 'EOF' > "$HOME/.config/environment.d/cedilla.conf"
# Cedilha nativa para layout US-intl no KDE Plasma 6 Wayland
LC_CTYPE=pt_BR.UTF-8
XCOMPOSEFILE=%h/.XCompose
EOF

    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user unset-environment GTK_IM_MODULE QT_IM_MODULE XMODIFIERS INPUT_METHOD SDL_IM_MODULE 2>/dev/null || true
        systemctl --user set-environment \
            LC_CTYPE="pt_BR.UTF-8" \
            XCOMPOSEFILE="$HOME/.XCompose" 2>/dev/null || true
    fi

    # Configura perfil do Fcitx5 (garantindo que não seja sobrescrito no shutdown)
    mkdir -p "$HOME/.config/fcitx5"
    backup_if_exists "$HOME/.config/fcitx5/profile"
    pkill -9 -x fcitx5 2>/dev/null || true
    sleep 0.2

    cat << 'EOF' > "$HOME/.config/fcitx5/profile"
[Groups/0]
# Group Name
Name=Default
# Layout
Default Layout=us-intl
# Default Input Method
DefaultIM=keyboard-us-intl

[Groups/0/Items/0]
# Name
Name=keyboard-us-intl
# Layout
Layout=

[Groups/0/Items/1]
# Name
Name=keyboard-br-abnt2
# Layout
Layout=

[GroupOrder]
0=Default
EOF

    # Configura autostart do Fcitx5 no login
    mkdir -p "$HOME/.config/autostart"
    if [ -f /usr/share/applications/org.fcitx.Fcitx5.desktop ]; then
        cp /usr/share/applications/org.fcitx.Fcitx5.desktop "$HOME/.config/autostart/"
    fi

    # Inicia o daemon fcitx5 em background
    ( fcitx5 -d >/dev/null 2>&1 & ) || true
    sleep 0.3
    echo -e "    ${GREEN}[OK]${NC} Fcitx5 configurado e daemon ativo em background."
else
    cat << 'EOF' > "$HOME/.config/environment.d/cedilla.conf"
# Cedilha nativa para layout US-intl no KDE Plasma 6 Wayland
LC_CTYPE=pt_BR.UTF-8
XCOMPOSEFILE=%h/.XCompose
EOF

    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user set-environment LC_CTYPE="pt_BR.UTF-8" XCOMPOSEFILE="$HOME/.XCompose" 2>/dev/null || true
    fi
fi
echo -e "    ${GREEN}[OK]${NC} ~/.config/environment.d/cedilla.conf gravado (LC_CTYPE=pt_BR.UTF-8)."

# Suporte ao shell Fish
if [ -d "$HOME/.config/fish" ]; then
    mkdir -p "$HOME/.config/fish/conf.d"
    backup_if_exists "$HOME/.config/fish/conf.d/cedilla.fish"
    cat << 'EOF' > "$HOME/.config/fish/conf.d/cedilla.fish"
# Cedilha nativa no layout US-intl (KDE Wayland Suite)
# GTK_IM_MODULE/QT_IM_MODULE=fcitx não são setados aqui: forçariam todo app
# Qt/GTK a passar pelo Fcitx5, quebrando Ctrl+C no ABNT2.
set -gx LC_CTYPE pt_BR.UTF-8
set -gx XCOMPOSEFILE $HOME/.XCompose
EOF
    echo -e "    ${GREEN}[OK]${NC} ~/.config/fish/conf.d/cedilla.fish configurado."
fi

# Exporta na sessão atual
export LC_CTYPE="pt_BR.UTF-8"
export XCOMPOSEFILE="$HOME/.XCompose"
unset GTK_IM_MODULE QT_IM_MODULE XMODIFIERS 2>/dev/null || true

echo -e "${BOLD}${BLUE}==> [3/6] Configurando suporte a cedilha nativo via ~/.XCompose...${NC}"
backup_if_exists "$HOME/.XCompose"

cat << 'EOF' > "$HOME/.XCompose"
include "%L"

# Overrides explícitos para garantir cedilha (' + c -> ç / ' + C -> Ç)
<dead_acute> <c> : "ç" ccedilla
<dead_acute> <C> : "Ç" Ccedilla
<acute> <c> : "ç" ccedilla
<acute> <C> : "Ç" Ccedilla
<dead_acute> <dead_acute> : "´" acute
<dead_acute> <apostrophe> : "´" acute
<dead_acute> <space> : "'" apostrophe
EOF
echo -e "    ${GREEN}[OK]${NC} ~/.XCompose configurado para ' + c -> ç."

echo -e "${BOLD}${BLUE}==> [4/6] Configurando flags de Wayland e IME para Chrome, Orca e Electron...${NC}"

configure_app_flags() {
    local conf_file="$1"
    backup_if_exists "$conf_file"
    mkdir -p "$(dirname "$conf_file")"
    cat << 'EOF' > "$conf_file"
--ozone-platform-hint=auto
--enable-features=WaylandWindowDecorations
--enable-wayland-ime
EOF
}

FLAG_FILES=(
    "$HOME/.config/chrome-flags.conf"
    "$HOME/.config/chromium-flags.conf"
    "$HOME/.config/brave-flags.conf"
    "$HOME/.config/electron-flags.conf"
    "$HOME/.config/code-flags.conf"
    "$HOME/.config/orca-flags.conf"
)

for ver in $(seq 28 34); do
    FLAG_FILES+=("$HOME/.config/electron${ver}-flags.conf")
done

for f in "${FLAG_FILES[@]}"; do
    configure_app_flags "$f"
done
echo -e "    ${GREEN}[OK]${NC} Flags de Wayland IME configuradas para Chrome, Chromium, Brave, Orca, Code e Electron."

echo -e "${BOLD}${BLUE}==> [5/6] Desbloqueando e garantindo backend de clipboard Wayland (wl-clipboard)...${NC}"
pkill -9 xsel 2>/dev/null || true

if command -v wl-copy >/dev/null 2>&1; then
    echo -e "    ${GREEN}[OK]${NC} wl-clipboard ativo (área de transferência nativa Wayland pronta)."
fi

echo -e "${BOLD}${BLUE}==> [6/6] Gravando configuração de layout no KDE Plasma 6 com notificação...${NC}"
backup_if_exists "$HOME/.config/kxkbrc"

kwriteconfig6 --file kxkbrc --group Layout --key Use true --notify
kwriteconfig6 --file kxkbrc --group Layout --key LayoutList "br,us" --notify
kwriteconfig6 --file kxkbrc --group Layout --key VariantList "abnt2,alt-intl" --notify
kwriteconfig6 --file kxkbrc --group Layout --key DisplayNames "," --notify
echo -e "    ${GREEN}[OK]${NC} kxkbrc atualizado com flag --notify (br abnt2 / us alt-intl)."

# Sincronização via D-Bus
if command -v qdbus6 >/dev/null 2>&1; then
    QDBUS="qdbus6"
elif command -v qdbus >/dev/null 2>&1; then
    QDBUS="qdbus"
elif [ -x /usr/lib/qt6/bin/qdbus ]; then
    QDBUS="/usr/lib/qt6/bin/qdbus"
else
    QDBUS=""
fi

if [ -n "$QDBUS" ]; then
    ACTIVE_LAYOUT="$("$QDBUS" --literal org.kde.keyboard /Layouts org.kde.KeyboardLayouts.getLayoutsList 2>/dev/null || echo 'indisponivel')"
    ACTIVE_IDX="$("$QDBUS" org.kde.keyboard /Layouts org.kde.KeyboardLayouts.getLayout 2>/dev/null || echo '0')"
    echo "    Layouts ativos: $ACTIVE_LAYOUT"
    echo "    Índice ativo atual: $ACTIVE_IDX"
fi

if [ "$HAS_FCITX5" -eq 0 ]; then
    echo ""
    echo -e "${YELLOW}[DICA] Para que o Chrome/Orca no Wayland processe '${BOLD}'+c${NC}${YELLOW} como '${BOLD}ç${NC}${YELLOW}' nativamente, instale o Fcitx5:${NC}"
    echo -e "    ${BOLD}sudo pacman -S --needed fcitx5-im fcitx5-gtk fcitx5-qt fcitx5-configtool${NC}"
    echo -e "    Depois, execute novamente: ${BOLD}./bin/kde-config fix-keyboard${NC}"
fi

echo -e "${GREEN}==> [SUCESSO] Teclado, cedilha e clipboard configurados com sucesso!${NC}"
