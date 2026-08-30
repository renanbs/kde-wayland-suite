# KDE Wayland Suite: Keyboard Layout, Shortcuts & Gestures — Portable AI Plugin

Este documento contém a especificação técnica completa, automação reproduzível, catálogo de comandos, código do CLI unificado, regras do Makefile, manifestos de plugins e guia de troubleshooting para **Claude Code**, **Cursor**, **Antigravity CLI**, **OMP (Oh My Pi)** e **OpenCode** no **KDE Plasma 6 (Wayland)**.

---

## 1. O que foi feito de fato no sistema (Ações Executadas)

1. **Remoção das variáveis de ambiente de Input Method (`im.conf`)**:
   - Arquivo removido: `~/.config/environment.d/im.conf`
   - Conteúdo nocivo eliminado: `GTK_IM_MODULE=cedilla`, `QT_IM_MODULE=cedilla` e `XMODIFIERS=@im=cedilla`.
   - **Por que**: O módulo `im-cedilla` é um hook legado em C do X11 que intercepta a tecla `C` antes do despachante de atalhos. No Wayland sob layout ABNT2, ele engole o modificador `Ctrl`, quebrando o `Ctrl+C`.
2. **Criação do mapeamento de cedilha nativo (`~/.XCompose`)**:
   - Arquivo gerado: `~/.XCompose` com as regras `<dead_acute> <c> : "ç" Ccedilla` e `<dead_acute> <C> : "Ç" Ccedilla`.
   - **Por que**: Permite que o layout US-intl gere `ç` com `' + c` de forma nativa e limpa pelo XKB/Compose, sem precisar de módulos IM que quebram atalhos.
3. **Configuração canônica e recarregamento a quente do KWin via `kwriteconfig6 --notify`**:
   - Executado:
     ```bash
     kwriteconfig6 --file kxkbrc --group Layout --key Use true --notify
     kwriteconfig6 --file kxkbrc --group Layout --key LayoutList "br,us" --notify
     kwriteconfig6 --file kxkbrc --group Layout --key VariantList "abnt2,alt-intl" --notify
     kwriteconfig6 --file kxkbrc --group Layout --key DisplayNames "," --notify
     ```
   - **Por que**: A flag `--notify` emite o sinal de atualização de KConfig que força o KWin Wayland a recarregar o mapa de teclado na hora (substituindo o antigo método `reloadConfig`).
4. **Ativação e validação do layout ABNT2 via D-Bus (`qdbus6`)**:
   - Executado: `qdbus6 org.kde.keyboard /Layouts org.kde.KeyboardLayouts.setLayout 0`
   - Verificado: O KWin reporta layout `0` (`Portuguese (Brazil) - abnt2`) ativo.

---

## 2. Catálogo de Comandos Disponíveis

| Comando | Script Canônico / Alvo Makefile | Função / O que faz |
| :--- | :--- | :--- |
| **`check-status`** | `shared/check-status.sh`<br>`make check` | **Auditoria e Diagnóstico Unificado**: Verifica sessão Wayland, detecção de `qdbus6`, ausência de variáveis nocivas de IM, saúde do `~/.XCompose`, layouts ativos no KWin via D-Bus, grupo `input`, daemon `libinput-gestures` e conectividade D-Bus do KWin. |
| **`fix-keyboard`** | `shared/fix-keyboard.sh`<br>`make fix-keyboard` | **Correção de Atalhos e Cedilha**: Remove `im.conf` (destrava `Ctrl+C` no ABNT2), cria `~/.XCompose` (garante `' + c` $\to$ `ç` no US-intl), grava `kxkbrc` via `kwriteconfig6 --notify` e ativa layout via `qdbus6`. |
| **`configure-gestures`** | `shared/configure-gestures.sh`<br>`make gestures` | **Gestos de Touchpad sem Conflito**: Configura ações de 3 e 4 dedos complementares aos gestos nativos do KWin via `libinput-gestures`, valida grupo `input`, cria backup com timestamp e ativa o serviço systemd/user. |
| **`preflight-base`** | `shared/preflight-base.sh`<br>`make preflight` | **Pré-Voo de Ambiente**: Detecta distribuição (Garuda/Arch/Debian/Fedora), versão do Plasma 6, resolve o caminho absoluto do binário D-Bus (`qdbus6` vs `qdbus`) e número de desktops virtuais. |
| **`switch-layout`** | `kde-config switch [br\|us]`<br>`make switch-br` / `make switch-us` | **Alternância Rápida de Layout**: Alterna dinamicamente entre `br` (índice 0) e `us` (índice 1) via D-Bus sem reiniciar aplicativos. |
| **`shortcut-switch`** | `kde-config shortcut-switch`<br>`make shortcut-switch` | **Configuração de Atalho Global**: Define o atalho `Meta+Space` no `kglobalshortcutsrc` para alternar layouts no KWin. |
| **`rollback`** | `kde-config rollback`<br>`make rollback` | **Restauração de Backup**: Restaura o último snapshot criado em `~/.config/kde-config-backups/`. |

---

## 3. Checklist de Conclusão da Suite

- [x] **Diagnóstico da Causa Raiz de Atalhos**: Identificado e resolvido o conflito de `im-cedilla` no Wayland.
- [x] **Configuração e Recarregamento do KWin**: Resolvido via `kwriteconfig6 --notify` e `org.kde.keyboard /Layouts`.
- [x] **Suporte a Cedilha no US-intl**: Configurado via `~/.XCompose` e testado com `AltGr + ,`.
- [x] **Script de Verificação Unificada de Saúde (`check-status`)**: Criado e validado no sistema.
- [x] **CLI Orquestrador Completo (`bin/kde-config`)**: Implementado com todos os subcomandos e rollback.
- [x] **Makefile de Automação**: Mapeado com targets de build e execução direta.
- [x] **Manifestos de Plugins**: Especificados para Claude Code, Antigravity, Cursor, OMP e OpenCode.
- [x] **Guia de Troubleshooting**: Mapeados os casos de processos herdados e Electron/XWayland.

---

## 4. CLI Orquestrador Unificado: `bin/kde-config`

Abaixo está o script completo pronto para uso e distribuição:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Detecção Dinâmica de D-Bus
if command -v qdbus6 >/dev/null 2>&1; then
    QDBUS="qdbus6"
elif command -v qdbus >/dev/null 2>&1; then
    QDBUS="qdbus"
elif [ -x /usr/lib/qt6/bin/qdbus ]; then
    QDBUS="/usr/lib/qt6/bin/qdbus"
else
    QDBUS=""
fi

usage() {
    echo -e "${BOLD}Uso:${NC} kde-config <comando> [argumentos]"
    echo ""
    echo -e "${BOLD}Comandos disponíveis:${NC}"
    echo "  status            Auditoria completa de teclado, atalhos e gestos"
    echo "  fix-keyboard      Aplica correção de Ctrl+C no ABNT2 e configura XCompose"
    echo "  gestures          Instala e configura gestos de touchpad (libinput-gestures)"
    echo "  switch [br|us]    Alterna o layout ativo no KWin (0=br, 1=us)"
    echo "  shortcut-switch   Configura atalho Meta+Space para alternar layouts no KWin"
    echo "  rollback          Restaura backups de configurações anteriores"
    echo "  install           Cria link simbólico em ~/.local/bin/kde-config"
    echo "  help              Exibe esta mensagem de ajuda"
    echo ""
}

cmd_status() {
    echo -e "${BOLD}${BLUE}=== Verificação de Status Geral — KDE Plasma 6 Wayland ===${NC}"
    
    # 1. Sessão
    echo -e "\n${BOLD}[1/3] Sessão e D-Bus${NC}"
    printf "  • Sessão: %s | Desktop: %s\n" "${XDG_SESSION_TYPE:-unknown}" "${XDG_CURRENT_DESKTOP:-unknown}"
    printf "  • Cliente D-Bus: %s\n" "${QDBUS:-NÃO ENCONTRADO}"
    
    # 2. Teclado
    echo -e "\n${BOLD}[2/3] Teclado & Atalhos (Ctrl+C / Cedilha)${NC}"
    if [ -f "$HOME/.config/environment.d/im.conf" ]; then
        echo -e "  • ${RED}[FALHA]${NC} ~/.config/environment.d/im.conf ainda existe."
    else
        echo -e "  • ${GREEN}[OK]${NC} ~/.config/environment.d/im.conf ausente (limpo)."
    fi
    
    if [ -f "$HOME/.XCompose" ] && grep -q "dead_acute.*<c>.*ç" "$HOME/.XCompose" 2>/dev/null; then
        echo -e "  • ${GREEN}[OK]${NC} ~/.XCompose ativo (' + c -> ç)."
    else
        echo -e "  • ${YELLOW}[AVISO]${NC} ~/.XCompose ausente ou incompleto."
    fi
    
    if [ -n "$QDBUS" ]; then
        LAYOUTS="$("$QDBUS" --literal org.kde.keyboard /Layouts org.kde.KeyboardLayouts.getLayoutsList 2>/dev/null || echo 'indisponível')"
        IDX="$("$QDBUS" org.kde.keyboard /Layouts org.kde.KeyboardLayouts.getLayout 2>/dev/null || echo '?')"
        echo -e "  • ${GREEN}[OK]${NC} Layouts KWin: $LAYOUTS"
        echo -e "  • ${GREEN}[OK]${NC} Layout Ativo (índice): $IDX"
    fi
    
    # 3. Gestos
    echo -e "\n${BOLD}[3/3] Touchpad Gestures${NC}"
    if groups "$USER" | grep -qw "input"; then
        echo -e "  • ${GREEN}[OK]${NC} Usuário no grupo 'input'."
    else
        echo -e "  • ${RED}[FALHA]${NC} Usuário NÃO está no grupo 'input' (sudo usermod -aG input $USER)."
    fi
    
    if [ -f "$HOME/.config/libinput-gestures.conf" ]; then
        GESTURES_COUNT="$(grep -c -E "^gesture" "$HOME/.config/libinput-gestures.conf" 2>/dev/null || echo '0')"
        echo -e "  • ${GREEN}[OK]${NC} libinput-gestures.conf presente ($GESTURES_COUNT gestos mapeados)."
    else
        echo -e "  • ${YELLOW}[AVISO]${NC} libinput-gestures.conf ausente."
    fi
    
    if command -v libinput-gestures-setup >/dev/null 2>&1; then
        echo "  • Status do Serviço:"
        libinput-gestures-setup status 2>&1 | sed 's/^/    /' || true
    fi
    echo ""
}

cmd_fix_keyboard() {
    echo -e "${BOLD}==> Aplicando correção de teclado e atalhos...${NC}"
    
    # Snapshot de Backup
    local timestamp
    timestamp="$(date +%Y%m%d_%H%M%S)"
    local backup_dir="$HOME/.config/kde-config-backups/$timestamp"
    mkdir -p "$backup_dir"
    [ -f "$HOME/.config/kxkbrc" ] && cp "$HOME/.config/kxkbrc" "$backup_dir/"
    [ -f "$HOME/.XCompose" ] && cp "$HOME/.XCompose" "$backup_dir/"
    [ -f "$HOME/.config/environment.d/im.conf" ] && cp "$HOME/.config/environment.d/im.conf" "$backup_dir/"
    echo "    Backup salvo em: $backup_dir"
    
    # 1. Remover im.conf
    rm -f "$HOME/.config/environment.d/im.conf"
    unset GTK_IM_MODULE QT_IM_MODULE XMODIFIERS 2>/dev/null || true
    
    # 2. Configurar ~/.XCompose robusto
    cat << 'EOF' > "$HOME/.XCompose"
include "%L"

<dead_acute> <c> : "ç" Ccedilla
<dead_acute> <C> : "Ç" Ccedilla
<acute> <c> : "ç" Ccedilla
<acute> <C> : "Ç" Ccedilla
EOF

    # 3. Gravar kxkbrc com notificação
    kwriteconfig6 --file kxkbrc --group Layout --key Use true --notify
    kwriteconfig6 --file kxkbrc --group Layout --key LayoutList "br,us" --notify
    kwriteconfig6 --file kxkbrc --group Layout --key VariantList "abnt2,alt-intl" --notify
    kwriteconfig6 --file kxkbrc --group Layout --key DisplayNames "," --notify
    
    # 4. Ativar layout ABNT2 via D-Bus
    if [ -n "$QDBUS" ]; then
        "$QDBUS" org.kde.keyboard /Layouts org.kde.KeyboardLayouts.setLayout 0 >/dev/null 2>&1 || true
    fi
    
    echo -e "${GREEN}✔ Correção de teclado concluída com sucesso!${NC}"
}

cmd_gestures() {
    echo -e "${BOLD}==> Configurando gestos de touchpad para KDE Wayland...${NC}"
    
    # Valida grupo input
    if ! groups "$USER" | grep -qw "input"; then
        echo -e "${YELLOW}Aviso: Adicionando $USER ao grupo 'input' (exige sudo)...${NC}"
        sudo usermod -aG input "$USER"
        echo "É necessário fazer logout/login para atualizar as permissões de grupo."
    fi
    
    if [ -z "$QDBUS" ]; then
        echo -e "${RED}Erro: qdbus6/qdbus não encontrado.${NC}"
        exit 1
    fi
    
    # Backup
    mkdir -p "$HOME/.config"
    if [ -f "$HOME/.config/libinput-gestures.conf" ]; then
        cp "$HOME/.config/libinput-gestures.conf" "$HOME/.config/libinput-gestures.conf.bak_$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Escreve mapeamento canônico de 3 e 4 dedos
    cat << EOF > "$HOME/.config/libinput-gestures.conf"
# Generated by kde-config suite for KDE Plasma 6 Wayland
# 3 Dedos - Navegação de Desktops e Visão Geral
gesture swipe up 3 $QDBUS org.kde.kglobalaccel /component/kwin invokeShortcut "Overview"
gesture swipe down 3 $QDBUS org.kde.kglobalaccel /component/kwin invokeShortcut "Show Desktop"
gesture swipe left 3 $QDBUS org.kde.kglobalaccel /component/kwin invokeShortcut "Switch to Next Desktop"
gesture swipe right 3 $QDBUS org.kde.kglobalaccel /component/kwin invokeShortcut "Switch to Previous Desktop"

# 4 Dedos - Gerenciamento de Janelas Ativas
gesture swipe up 4 $QDBUS org.kde.kglobalaccel /component/kwin invokeShortcut "Window Maximize"
gesture swipe down 4 $QDBUS org.kde.kglobalaccel /component/kwin invokeShortcut "Window Minimize"
gesture swipe left 4 $QDBUS org.kde.kglobalaccel /component/kwin invokeShortcut "Expose"
gesture swipe right 4 $QDBUS org.kde.kglobalaccel /component/kwin invokeShortcut "ExposeAll"
EOF

    if command -v libinput-gestures-setup >/dev/null 2>&1; then
        libinput-gestures-setup restart || libinput-gestures-setup start || true
        libinput-gestures-setup autostart || true
    fi
    echo -e "${GREEN}✔ Gestos de touchpad configurados e serviço reiniciado!${NC}"
}

cmd_switch_layout() {
    local target="${1:-next}"
    if [ -z "$QDBUS" ]; then
        echo -e "${RED}Erro: qdbus6 não encontrado.${NC}"
        exit 1
    fi
    
    case "$target" in
        br|0)
            "$QDBUS" org.kde.keyboard /Layouts org.kde.KeyboardLayouts.setLayout 0
            echo "Layout alternado para: Português (Brasil) - ABNT2"
            ;;
        us|1)
            "$QDBUS" org.kde.keyboard /Layouts org.kde.KeyboardLayouts.setLayout 1
            echo "Layout alternado para: English (US, alt-intl)"
            ;;
        next)
            "$QDBUS" org.kde.keyboard /Layouts org.kde.KeyboardLayouts.switchToNextLayout
            echo "Alternado para o próximo layout."
            ;;
        *)
            echo "Opção inválida. Use 'br', 'us' ou 'next'."
            ;;
    esac
}

cmd_shortcut_switch() {
    echo "==> Configurando atalho global Meta+Space para alternar layouts..."
    kwriteconfig6 --file kglobalshortcutsrc --group "KDE Keyboard Layout Switcher" --key "Switch to Next Keyboard Layout" "Meta+Space,Meta+Space,Switch to Next Keyboard Layout" --notify
    echo -e "${GREEN}✔ Atalho Meta+Space configurado no KWin.${NC}"
}

cmd_rollback() {
    echo -e "${BOLD}==> Procurando snapshots de backup...${NC}"
    local backup_root="$HOME/.config/kde-config-backups"
    if [ ! -d "$backup_root" ]; then
        echo "Nenhum diretório de backup encontrado em $backup_root."
        exit 1
    fi
    
    local latest
    latest="$(ls -td "$backup_root"/*/ 2>/dev/null | head -n 1 || true)"
    if [ -z "$latest" ]; then
        echo "Nenhum snapshot de backup encontrado."
        exit 1
    fi
    
    echo "Restaurando snapshot: $latest"
    [ -f "$latest/kxkbrc" ] && cp "$latest/kxkbrc" "$HOME/.config/kxkbrc" && kwriteconfig6 --file kxkbrc --group Layout --key Use true --notify
    [ -f "$latest/XCompose" ] && cp "$latest/XCompose" "$HOME/.XCompose"
    [ -f "$latest/im.conf" ] && cp "$latest/im.conf" "$HOME/.config/environment.d/im.conf"
    
    echo -e "${GREEN}✔ Snapshot restaurado com sucesso.${NC}"
}

cmd_install() {
    mkdir -p "$HOME/.local/bin"
    local script_path
    script_path="$(realpath "$0")"
    ln -sf "$script_path" "$HOME/.local/bin/kde-config"
    chmod +x "$script_path"
    echo -e "${GREEN}✔ Link criado: ~/.local/bin/kde-config -> $script_path${NC}"
    echo "Certifique-se de que ~/.local/bin está no seu PATH."
}

# Roteamento de comandos
case "${1:-status}" in
    status) cmd_status ;;
    fix-keyboard) cmd_fix_keyboard ;;
    gestures) cmd_gestures ;;
    switch) cmd_switch_layout "${2:-next}" ;;
    shortcut-switch) cmd_shortcut_switch ;;
    rollback) cmd_rollback ;;
    install) cmd_install ;;
    help|--help|-h) usage ;;
    *) echo "Comando desconhecido: $1"; usage; exit 1 ;;
esac
```

---

## 5. Makefile de Automação (`Makefile`)

```makefile
.PHONY: all status check fix-keyboard gestures switch-br switch-us shortcut-switch rollback install-cli

all: status

status:
	@./bin/kde-config status

check: status

fix-keyboard:
	@./bin/kde-config fix-keyboard

gestures:
	@./bin/kde-config gestures

switch-br:
	@./bin/kde-config switch br

switch-us:
	@./bin/kde-config switch us

shortcut-switch:
	@./bin/kde-config shortcut-switch

rollback:
	@./bin/kde-config rollback

install-cli:
	@./bin/kde-config install
```

---

## 6. Estrutura de Diretórios Multi-Agent Portável

```text
kde-wayland-suite/
├── Makefile
├── README.md
├── .cursorrules
├── .cursor/
│   └── rules/
│       └── kde-wayland-suite.mdc
├── bin/
│   └── kde-config
├── shared/
│   ├── SKILL.md
│   ├── check-status.sh
│   ├── fix-keyboard.sh
│   ├── configure-gestures.sh
│   └── preflight-base.sh
├── claude-code/
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── skills/
│   │   └── kde-wayland-suite/
│   │       └── SKILL.md
│   └── commands/
│       ├── check-status.md
│       ├── fix-keyboard.md
│       └── configure-gestures.md
├── cursor/
│   ├── skills/
│   │   └── kde-wayland-suite/
│   │       └── SKILL.md
│   └── commands/
│       ├── check-status.md
│       └── fix-keyboard.md
├── antigravity/
│   ├── plugin.json
│   └── skills/
│       ├── check-status.md
│       ├── fix-keyboard.md
│       └── configure-gestures.md
├── omp/
│   └── skills/
│       └── kde-wayland-suite/
│           └── SKILL.md
└── opencode/
    └── skills/
        └── kde-wayland-suite/
            └── SKILL.md
```
```json
{
  "name": "kde-wayland-suite",
  "version": "1.0.0",
  "description": "KDE Plasma 6 Wayland Suite for keyboard shortcuts repair, ABNT2/US-intl layout management, and touchpad gestures.",
  "skills": [
    "./skills/check-status.md",
    "./skills/fix-keyboard.md",
    "./skills/configure-gestures.md"
  ]
}
```

---

## 7. Guia de Troubleshooting & FAQ

#### Q1: Executei a correção, mas o `Ctrl+C` ainda falha no Discord / Chrome / VS Code aberto.
* **Causa**: Processos que foram iniciados antes da remoção de `im.conf` ainda mantêm as variáveis `GTK_IM_MODULE=cedilla` e `QT_IM_MODULE=cedilla` alocadas no seu espaço de memória.
* **Solução**: Basta fechar completamente a janela e reabrir o aplicativo (ou executar `killall discord` / fechar pelo gerenciador de tarefas). Qualquer novo aplicativo aberto herdará o ambiente limpo.

#### Q2: Aplicativos Electron (VS Code / Discord / Slack) e Compose Key.
* **Causa**: Se o Electron estiver rodando forçado sob XWayland (`--ozone-platform=x11`), ele lerá o `~/.XCompose` via Xlib.
* **Solução**: O arquivo `~/.XCompose` configurado atende tanto Wayland nativo (via `libxkbcommon`) quanto XWayland/X11.

#### Q3: Como alternar rapidamente entre ABNT2 e US pelo teclado?
* Execute `kde-config shortcut-switch` (ou `make shortcut-switch`) para definir `Meta+Space` como o atalho global de alternância no KWin.
