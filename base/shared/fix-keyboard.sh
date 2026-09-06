#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# fix-keyboard.sh — Correção de Atalhos, Cedilha e Clipboard no KDE Plasma 6 Wayland
# Garante dead_acute + c -> ç no layout US-intl (Chrome, Orca, Electron, GTK, Qt)
# via LC_CTYPE=pt_BR.UTF-8 (sem input method), e mantém Ctrl+<tecla> funcionando
# no ABNT2 — inclusive desativando o fcitx5, que quebra Ctrl+ sob Wayland.
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

# 2. Desativa o fcitx5 — ele quebra Ctrl+<tecla> no sistema inteiro sob Wayland.
#    Diagnosticado em produção: rodando como input method nativo do Wayland, o
#    fcitx5 faz grab do teclado e engole as combinações com Ctrl (copiar,
#    colar, desfazer, selecionar tudo) em Qt, GTK e Electron por igual —
#    enquanto letras normais continuam passando, o que torna o sintoma
#    confuso. Matar o processo restaura o Ctrl na hora; reiniciá-lo quebra de
#    novo, de forma determinística. E ele é dispensável: a cedilha funciona
#    nativamente via LC_CTYPE (passo 2 abaixo).
if [ -f "$HOME/.config/autostart/org.fcitx.Fcitx5.desktop" ]; then
    backup_if_exists "$HOME/.config/autostart/org.fcitx.Fcitx5.desktop"
    rm -f "$HOME/.config/autostart/org.fcitx.Fcitx5.desktop"
    echo -e "    ${GREEN}[OK]${NC} Autostart do fcitx5 desativado (quebra Ctrl+<tecla>; não é necessário para a cedilha)."
fi
if pgrep -x fcitx5 >/dev/null 2>&1; then
    pkill -x fcitx5 2>/dev/null || true
    echo -e "    ${GREEN}[OK]${NC} Processo fcitx5 encerrado (restaura Ctrl+<tecla> imediatamente)."
fi

echo -e "${BOLD}${BLUE}==> [2/6] Configurando locale de composição (cedilha)...${NC}"
mkdir -p "$HOME/.config/environment.d"
backup_if_exists "$HOME/.config/environment.d/cedilla.conf"

# A cedilha NÃO precisa de input method (fcitx5/ibus). A tabela de composição
# do sistema para pt_BR (/usr/share/X11/locale/pt_BR.UTF-8/Compose) já mapeia
# <dead_acute> <c> -> "ç" nativamente. Basta o processo do app ter
# LC_CTYPE=pt_BR.UTF-8 para o libxkbcommon escolher essa tabela em vez da
# en_US, que mapeia a MESMA sequência para "ć" (c com agudo).
# Verificado em produção: Konsole com LC_CTYPE=pt_BR.UTF-8 compõe "ç";
# app Electron sem LC_CTYPE no ambiente compõe "ć".
cat << 'EOF' > "$HOME/.config/environment.d/cedilla.conf"
# Cedilha nativa (KDE Wayland Suite)
# Seleciona a tabela de composição pt_BR do sistema, que já define
# <dead_acute> <c> -> "ç". Sem isto, o app cai na tabela en_US, que dá "ć".
LC_CTYPE=pt_BR.UTF-8
EOF

if command -v systemctl >/dev/null 2>&1; then
    systemctl --user unset-environment GTK_IM_MODULE QT_IM_MODULE XMODIFIERS INPUT_METHOD SDL_IM_MODULE 2>/dev/null || true
    systemctl --user set-environment LC_CTYPE="pt_BR.UTF-8" 2>/dev/null || true
fi
echo -e "    ${GREEN}[OK]${NC} ~/.config/environment.d/cedilla.conf gravado (LC_CTYPE=pt_BR.UTF-8)."
echo -e "    ${BLUE}[INFO]${NC} Vale para apps iniciados a partir do próximo login (processos já abertos mantêm o ambiente antigo)."

# Suporte ao shell Fish
if [ -d "$HOME/.config/fish" ]; then
    mkdir -p "$HOME/.config/fish/conf.d"
    backup_if_exists "$HOME/.config/fish/conf.d/cedilla.fish"
    cat << 'EOF' > "$HOME/.config/fish/conf.d/cedilla.fish"
# Cedilha nativa (KDE Wayland Suite)
# Seleciona a tabela de composição pt_BR do sistema, que já define
# <dead_acute> <c> -> "ç". Nenhum input method (fcitx5/ibus) é necessário —
# e o fcitx5, sob Wayland, quebra Ctrl+<tecla> no sistema inteiro.
set -gx LC_CTYPE pt_BR.UTF-8
EOF
    echo -e "    ${GREEN}[OK]${NC} ~/.config/fish/conf.d/cedilla.fish configurado."
fi

# Exporta na sessão atual
export LC_CTYPE="pt_BR.UTF-8"
unset GTK_IM_MODULE QT_IM_MODULE XMODIFIERS 2>/dev/null || true

echo -e "${BOLD}${BLUE}==> [3/6] Verificando ~/.XCompose (não é mais necessário)...${NC}"
# Versões anteriores desta suite escreviam um ~/.XCompose com regras de
# cedilha. Elas são duplicatas exatas do que a tabela pt_BR do sistema já
# define, e o libxkbcommon as descarta com "this compose sequence is a
# duplicate of another; skipping line" (visível no journal do kwin_wayland).
# Não geramos mais esse arquivo. Se o conteúdo for o gerado por versões
# antigas, removemos com backup; conteúdo customizado pelo usuário é mantido.
if [ -f "$HOME/.XCompose" ] && grep -q "Overrides explícitos para garantir cedilha" "$HOME/.XCompose" 2>/dev/null; then
    backup_if_exists "$HOME/.XCompose"
    rm -f "$HOME/.XCompose"
    echo -e "    ${GREEN}[OK]${NC} ~/.XCompose de versões antigas removido (redundante). Backup em $backup_dir."
elif [ -f "$HOME/.XCompose" ]; then
    echo -e "    ${BLUE}[INFO]${NC} ~/.XCompose existente parece customizado por você — preservado sem alterações."
else
    echo -e "    ${GREEN}[OK]${NC} Sem ~/.XCompose (a tabela pt_BR do sistema já cobre a cedilha)."
fi

echo -e "${BOLD}${BLUE}==> [4/6] Configurando flags de Wayland para Chrome, Orca e Electron...${NC}"

# --enable-wayland-ime NÃO é usada: ela existe para o app conversar com um
# input method via protocolo Wayland, e esta suite não usa mais nenhum (o
# fcitx5 quebra Ctrl+<tecla>). A composição de cedilha é feita pelo próprio
# toolkit a partir da tabela pt_BR selecionada por LC_CTYPE.
configure_app_flags() {
    local conf_file="$1"
    backup_if_exists "$conf_file"
    mkdir -p "$(dirname "$conf_file")"
    cat << 'EOF' > "$conf_file"
--ozone-platform-hint=auto
--enable-features=WaylandWindowDecorations
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

# IMPORTANTE: LayoutList e VariantList precisam ter o mesmo número de entradas
# em TODO momento em que o KWin recarrega o kxkbrc, senão ele falha ao compilar
# o keymap ("XKB: More/Less layouts than variants") e o Ctrl+<tecla> para de
# funcionar em TODO o sistema até um reboot completo (visto em produção:
# kwin_wayland[...]: XKB: More layouts than variants: "br,us" vs. "intl." ->
# "Could not create xkb keymap from configuration"). Por isso: grava Use,
# VariantList e DisplayNames SEM --notify primeiro (não dispara reload no meio
# do caminho com listas de tamanhos diferentes), e só notifica o KWin na
# ÚLTIMA escrita (LayoutList), quando o arquivo inteiro já está consistente.
kwriteconfig6 --file kxkbrc --group Layout --key Use true
kwriteconfig6 --file kxkbrc --group Layout --key VariantList "abnt2,alt-intl"
kwriteconfig6 --file kxkbrc --group Layout --key DisplayNames ","
kwriteconfig6 --file kxkbrc --group Layout --key LayoutList "br,us" --notify
echo -e "    ${GREEN}[OK]${NC} kxkbrc atualizado com flag --notify (br abnt2 / us alt-intl)."

# Auto-cura opcional contra bug conhecido do KWin/Plasma: ao encerrar a
# sessão, o Plasma às vezes regrava kxkbrc mantendo só o layout que estava
# ativo no momento do logout, descartando o resto da LayoutList (reproduzido
# em log: "kwin_wayland: XKB: More layouts than variants"). Isso não é
# causado por nenhum comando desta suite, mas como não há como corrigir o
# bug do KWin em si, oferecemos reaplicar o kxkbrc correto a cada login via
# autostart. Só é instalado se o usuário optar (KDE_SUITE_LAYOUT_AUTOHEAL=1),
# pois modifica o autostart da sessão — quem estiver rodando o script via
# skill/IA deve perguntar ao usuário antes de habilitar.
autoheal_desktop="$HOME/.config/autostart/kde-wayland-suite-restore-layout.desktop"
restore_script="$HOME/.local/bin/kde-wayland-suite-restore-layout.sh"
if [ "${KDE_SUITE_LAYOUT_AUTOHEAL:-0}" = "1" ]; then
    mkdir -p "$HOME/.config/autostart" "$HOME/.local/bin"
    cat << 'EOF' > "$restore_script"
#!/usr/bin/env bash
# Reaplica o layout de teclado (br abnt2 / us alt-intl) a cada login, pois o
# Plasma pode colapsar kxkbrc para um único layout ao encerrar a sessão
# anterior (bug conhecido do KWin/Plasma, fora do controle desta suite).
#
# IMPORTANTE: se LayoutList tiver mais entradas que VariantList no momento em
# que o KWin recarrega o kxkbrc (--notify), a compilação do keymap falha
# ("XKB: More layouts than variants") e o Ctrl+<tecla> para de funcionar no
# sistema inteiro até um reboot completo. Por isso grava VariantList/
# DisplayNames sem --notify primeiro, e só notifica na última escrita
# (LayoutList), quando o arquivo já está inteiro consistente.
sleep 3
kwriteconfig6 --file kxkbrc --group Layout --key Use true
kwriteconfig6 --file kxkbrc --group Layout --key VariantList "abnt2,alt-intl"
kwriteconfig6 --file kxkbrc --group Layout --key DisplayNames ","
kwriteconfig6 --file kxkbrc --group Layout --key LayoutList "br,us" --notify
EOF
    chmod +x "$restore_script"

    cat << EOF > "$autoheal_desktop"
[Desktop Entry]
Type=Application
Name=KDE Wayland Suite - Restaurar Layout de Teclado
Exec=$restore_script
X-KDE-autostart-phase=2
NoDisplay=true
EOF
    echo -e "    ${GREEN}[OK]${NC} Autostart de auto-cura do layout instalado (protege contra o bug de colapso do kxkbrc no reboot)."
else
    echo -e "    ${YELLOW}[INFO]${NC} Auto-cura do layout no login não instalada (opcional). Para habilitar: KDE_SUITE_LAYOUT_AUTOHEAL=1 ./bin/kde-config fix-keyboard"
fi

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

echo ""
echo -e "${YELLOW}[NOTA]${NC} A cedilha (${BOLD}dead_acute + c${NC} -> ${BOLD}ç${NC}) depende de o app ter ${BOLD}LC_CTYPE=pt_BR.UTF-8${NC}"
echo -e "       no ambiente. Processos já abertos mantêm o ambiente antigo — faça logout/login"
echo -e "       para que toda a sessão (incluindo apps Electron) herde o locale correto."

echo -e "${GREEN}==> [SUCESSO] Teclado, cedilha e clipboard configurados com sucesso!${NC}"
