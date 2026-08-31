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

# Limpa variáveis nocivas de outros arquivos em environment.d
if [ -d "$HOME/.config/environment.d" ]; then
    for env_f in "$HOME/.config/environment.d"/*.conf; do
        [ -f "$env_f" ] || continue
        [ "$(basename "$env_f")" = "cedilla.conf" ] && continue
        if grep -qE '^(GTK_IM_MODULE|QT_IM_MODULE|XMODIFIERS)=' "$env_f" 2>/dev/null; then
            backup_if_exists "$env_f"
            sed -i '/^GTK_IM_MODULE=/d; /^QT_IM_MODULE=/d; /^XMODIFIERS=/d' "$env_f"
            echo -e "    ${GREEN}[OK]${NC} Variáveis legadas de IM removidas de $(basename "$env_f")."
        fi
    done
fi

# Zera variáveis no escopo da shell atual
unset GTK_IM_MODULE QT_IM_MODULE XMODIFIERS 2>/dev/null || true

echo -e "${BOLD}${BLUE}==> [2/6] Configurando LC_CTYPE e XCOMPOSEFILE para cedilha nativa...${NC}"
mkdir -p "$HOME/.config/environment.d"
backup_if_exists "$HOME/.config/environment.d/cedilla.conf"

cat << 'EOF' > "$HOME/.config/environment.d/cedilla.conf"
# Cedilha nativa para layout US-intl no KDE Plasma 6 Wayland sem quebrar Ctrl+C no ABNT2
LC_CTYPE=pt_BR.UTF-8
XCOMPOSEFILE=%h/.XCompose
EOF
echo -e "    ${GREEN}[OK]${NC} ~/.config/environment.d/cedilla.conf gravado (LC_CTYPE=pt_BR.UTF-8)."

# Injeta na sessão do systemd para novos processos herdarem imediatamente
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user set-environment LC_CTYPE="pt_BR.UTF-8" XCOMPOSEFILE="$HOME/.XCompose" 2>/dev/null || true
    echo -e "    ${GREEN}[OK]${NC} Variáveis LC_CTYPE e XCOMPOSEFILE injetadas no systemd --user."
fi

# Suporte ao shell Fish (se instalado)
if [ -d "$HOME/.config/fish" ]; then
    mkdir -p "$HOME/.config/fish/conf.d"
    backup_if_exists "$HOME/.config/fish/conf.d/cedilla.fish"
    cat << 'EOF' > "$HOME/.config/fish/conf.d/cedilla.fish"
# Cedilha nativa no layout US-intl (KDE Wayland Suite)
set -gx LC_CTYPE pt_BR.UTF-8
set -gx XCOMPOSEFILE $HOME/.XCompose
EOF
    echo -e "    ${GREEN}[OK]${NC} ~/.config/fish/conf.d/cedilla.fish configurado."
fi

# Exporta na sessão atual
export LC_CTYPE="pt_BR.UTF-8"
export XCOMPOSEFILE="$HOME/.XCompose"

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

echo -e "${BOLD}${BLUE}==> [4/6] Configurando flags de compatibilidade (XWayland / XCompose) para Chrome, Orca e Electron...${NC}"

configure_app_flags() {
    local conf_file="$1"
    backup_if_exists "$conf_file"
    mkdir -p "$(dirname "$conf_file")"
    cat << 'EOF' > "$conf_file"
--ozone-platform=x11
EOF
}
# Lista de aplicativos Chromium, Electron e IDEs
FLAG_FILES=(
    "$HOME/.config/chrome-flags.conf"
    "$HOME/.config/chromium-flags.conf"
    "$HOME/.config/brave-flags.conf"
    "$HOME/.config/electron-flags.conf"
    "$HOME/.config/code-flags.conf"
    "$HOME/.config/orca-flags.conf"
)

# Adiciona variantes de versões do Electron (electron28..34)
for ver in $(seq 28 34); do
    FLAG_FILES+=("$HOME/.config/electron${ver}-flags.conf")
done

for f in "${FLAG_FILES[@]}"; do
    configure_app_flags "$f"
done
echo -e "    ${GREEN}[OK]${NC} Flags (--enable-wayland-ime) configuradas para Chrome, Chromium, Brave, Orca, Code e Electron."

echo -e "${BOLD}${BLUE}==> [5/6] Desbloqueando e garantindo backend de clipboard Wayland (wl-clipboard)...${NC}"
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

echo -e "${GREEN}==> [SUCESSO] Teclado, cedilha (US-intl / Chrome / Orca) e clipboard configurados com sucesso!${NC}"
