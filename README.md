# KDE Wayland Suite: Keyboard Layout, Shortcuts & Gestures

[![KDE Plasma 6](https://img.shields.io/badge/KDE%20Plasma-6-blue.svg)](https://kde.org/plasma-desktop/)
[![Wayland Ready](https://img.shields.io/badge/Wayland-Native-success.svg)](https://wayland.freedesktop.org/)
[![Multi-Harness Plugin](https://img.shields.io/badge/AI%20Harnesses-Claude%20%7C%20Cursor%20%7C%20Antigravity%20%7C%20OMP%20%7C%20OpenCode-purple.svg)](#-passo-a-passo-por-ferramenta-de-ia)

Plugin e suíte de automação portátil para **KDE Plasma 6 (Wayland)** projetado para corrigir problemas de atalhos e gerenciar toda a pilha de entrada no Linux — cobrindo **teclado**, **cedilha nativa em Chrome/Orca/Electron**, **atalhos (Ctrl+C)** e **gestos de touchpad** sem concorrência com o KWin.

Compatível com **Claude Code**, **Cursor IDE & CLI**, **Antigravity CLI**, **OMP (Oh My Pi)** e **OpenCode**, além de funcionar diretamente pelo terminal via CLI (`kde-config`) ou `Makefile`.

---

## 🎯 Problemas Resolvidos

1. **`Ctrl+C` quebrado no layout ABNT2 (`br`)**:
   - **Causa**: Módulos legados `GTK_IM_MODULE=cedilla` / `QT_IM_MODULE=cedilla` em `~/.config/environment.d/im.conf` interceptavam a tecla `C` em baixo nível e suprimiam modificadores no Wayland.
   - **Solução**: Remoção limpa das variáveis nocivas de IM e recarregamento a quente via KWin.
2. **Cedilha no layout US-intl (`' + c` $\to$ `ç` em Chrome, Orca IDE, Electron, GTK e Qt)**:
   - **Causa**: O locale padrão `en_US.UTF-8` mapeia `<dead_acute> <c>` para `ć` (c-acute). Além disso, navegadores Chromium e apps Electron no Wayland usam `CharacterComposer` interno que ignora `~/.XCompose` sem as flags de IME.
   - **Solução**:
     - Configuração de `LC_CTYPE=pt_BR.UTF-8` e `XCOMPOSEFILE` em `~/.config/environment.d/cedilla.conf` e `systemd --user`.
     - Configuração de `~/.XCompose` nativo com regras completas de cedilha (`<dead_acute> <c> : "ç"` e `<dead_acute> <C> : "Ç"`).
     - Injeção das flags `--enable-wayland-ime` e `--ozone-platform-hint=auto` nos arquivos de configuração de flags (`chrome-flags.conf`, `chromium-flags.conf`, `orca-flags.conf`, `code-flags.conf`, `electron-flags.conf`).
     - **Importante**: `GTK_IM_MODULE`/`QT_IM_MODULE=fcitx` **não** são setados globalmente — isso forçaria todo app Qt/GTK (Konsole, Dolphin, Kate...) a passar pelo Fcitx5, quebrando `Ctrl+C` no ABNT2. Chrome/Orca/Electron falam com o Fcitx5 diretamente via protocolo Wayland (as flags acima), sem precisar dessas variáveis. `./bin/kde-config status` detecta e alerta se essas variáveis forem reintroduzidas.
3. **Gestos de Touchpad sem Conflito**:
   - **Solução**: Mapeamento de 3 e 4 dedos complementares às animações 1:1 nativas do KWin via `libinput-gestures` e D-Bus (`qdbus6`).
4. **Gerenciamento de Layouts no Plasma 6**:
   - Atualização atômica de `~/.config/kxkbrc` com `kwriteconfig6 --notify` e alternância via D-Bus (`org.kde.keyboard /Layouts`).
5. **Botões e Rolagem do Logitech MX Master 3S**:
   - **Causa**: O Logitech Options não roda nativamente no Linux; sem ele, os botões extras do mouse (botão de gesto, SmartShift) ficam sem função.
   - **Solução**: Instalação do `logiops` (AUR) e geração de `~/.config/logid.cfg` (linkado em `/etc/logid.cfg`, editável sem sudo) mapeando o botão de gesto para Overview (`Meta+W`), Mostrar Área de Trabalho (`Meta+D`) e troca de workspace (`Meta+Ctrl+Left/Right`, sem mover a janela ativa junto), além de fixar o SmartShift em rolagem livre (sem catraca).
6. **Troca de Workspace Não Reflete em Todas as Telas (Multi-Monitor)**:
   - **Causa**: Por padrão, o KWin trata os workspaces virtuais como globais e compartilhados entre monitores (`kwinrc [Windows] PerOutputVirtualDesktops=false`), então a troca pode não refletir corretamente conforme o monitor onde o cursor está.
   - **Solução**: Habilitação de `PerOutputVirtualDesktops=true` (equivalente a "Switch desktops independently for each screen" em System Settings → Área de Trabalho Virtual), aplicada automaticamente pelo `configure-mouse.sh`.

---

## 🚀 Passo a Passo de Uso

### 1. Uso Direto pelo Terminal

#### Via Makefile
```bash
# Auditoria de saúde do sistema (sessão, teclado, cedilha, IM e gestos)
make check
# ou: make status

# Aplicar correção de Ctrl+C no ABNT2 e suporte a cedilha no US-intl (Chrome/Orca)
make fix-keyboard

# Configurar gestos de 3 e 4 dedos no touchpad
make gestures

# Configurar o mouse Logitech MX Master 3S (logiops/logid)
make mouse

# Alternar layout ativo no KWin
make switch-br    # Ativa Português (Brasil) - ABNT2 (índice 0)
make switch-us    # Ativa English (US, alt-intl) (índice 1)

# Configurar atalho Meta+Space para alternar layouts no teclado
make shortcut-switch

# Instalar o comando 'kde-config' no seu PATH (~/.local/bin)
make install-cli
```

#### Via CLI Orquestrador (`bin/kde-config`)
```bash
./bin/kde-config status           # Auditoria completa (inclui simulação de compose e flags de apps)
./bin/kde-config fix-keyboard     # Corrige atalhos, cedilha e teclado
./bin/kde-config gestures         # Configura gestos de touchpad
./bin/kde-config mouse            # Configura o Logitech MX Master 3S (logiops)
./bin/kde-config switch [br|us]   # Alterna layout via D-Bus
./bin/kde-config shortcut-switch  # Ativa atalho Meta+Space
./bin/kde-config rollback         # Restaura último backup
```

---

## 🤖 Instalação e Uso em Outras Máquinas (Por Ferramenta de IA)

Para que qualquer outra pessoa instale e utilize esta suíte em sua própria máquina, siga as instruções da respectiva CLI:

### 1. OMP (Oh My Pi)
O **OMP** utiliza o comando nativo `/marketplace`:

```bash
# No chat do OMP (ou TUI):
/marketplace add renanbs/kde-wayland-suite
/marketplace install kde-wayland-suite@kde-wayland-suite

# Ou diretamente pelo terminal via CLI do OMP:
omp plugin marketplace add renanbs/kde-wayland-suite
omp plugin install kde-wayland-suite@kde-wayland-suite
```
* **Comandos disponíveis**: `/check-status`, `/fix-keyboard`, `/configure-gestures`, `/configure-mouse`, `/init`.
* **Skill nativa**: `skill://kde-wayland-suite`.

---

### 2. Claude Code
```bash
# No chat do Claude Code:
/plugin marketplace add renanbs/kde-wayland-suite
/plugin install kde-wayland-suite@kde-wayland-suite
```
* *Testando localmente sem GitHub:* `claude --plugin-dir ~/src/kde-wayland-suite`
* **Comandos disponíveis**: `/check-status`, `/fix-keyboard`, `/configure-gestures`, `/configure-mouse`, `/init`.
---

### 3. Cursor CLI & IDE (`cursor agent` / Headless)
```bash
# 1. Clonar e instalar o binário
git clone https://github.com/renanbs/kde-wayland-suite.git ~/src/kde-wayland-suite
cd ~/src/kde-wayland-suite && make install-cli

# 2. Para usar globalmente em qualquer projeto aberto no Cursor:
mkdir -p ~/.cursor/rules
cp .cursor/rules/kde-wayland-suite.mdc ~/.cursor/rules/
```
* O Cursor CLI e o Agent passam a aplicar as regras automaticamente em qualquer sessão via `.cursor/rules/kde-wayland-suite.mdc`.

---

### 4. Antigravity CLI
```bash
# 1. Clonar e instalar o binário
git clone https://github.com/renanbs/kde-wayland-suite.git ~/src/kde-wayland-suite
cd ~/src/kde-wayland-suite && make install-cli

# 2. Linkar como plugin no Antigravity
mkdir -p ~/.config/antigravity/plugins
ln -sf ~/src/kde-wayland-suite/antigravity ~/.config/antigravity/plugins/kde-wayland-suite
```

---

### 5. OpenCode
```bash
# 1. Clonar e instalar o binário
git clone https://github.com/renanbs/kde-wayland-suite.git ~/src/kde-wayland-suite
cd ~/src/kde-wayland-suite && make install-cli

# 2. Linkar a skill no OpenCode
mkdir -p ~/.config/opencode/skills
ln -sf ~/src/kde-wayland-suite/opencode/skills/kde-wayland-suite ~/.config/opencode/skills/
```
* Carrega a definição padrão localizada em `opencode/skills/kde-wayland-suite/SKILL.md`.

---

## 📂 Estrutura Portátil do Repositório

```text
kde-wayland-suite/
├── Makefile                      # Interface make para automações
├── README.md                     # Documentação geral
├── .cursorrules                  # Regras de contexto para Cursor CLI (raiz)
├── .cursor/                      # Regras nativas do Cursor IDE & CLI
│   └── rules/
│       └── kde-wayland-suite.mdc # Regra MDC com alwaysApply para Cursor Agent
├── bin/
│   └── kde-config                # CLI orquestrador unificado
├── shared/                       # Fonte Canônica da Verdade (Single Source of Truth)
│   ├── SKILL.md
│   ├── check-status.sh
│   ├── fix-keyboard.sh
│   ├── configure-gestures.sh
│   ├── configure-mouse.sh
│   └── preflight-base.sh
├── claude-code/                  # Plugin para Claude Code
│   ├── .claude-plugin/plugin.json
│   ├── skills/kde-wayland-suite/SKILL.md
│   └── commands/
│       ├── check-status.md
│       ├── fix-keyboard.md
│       ├── configure-gestures.md
│       └── configure-mouse.md
├── cursor/                       # Plugin e Rules para Cursor IDE
│   ├── skills/kde-wayland-suite/SKILL.md
│   └── commands/
│       ├── check-status.md
│       ├── fix-keyboard.md
│       └── configure-mouse.md
├── antigravity/                  # Plugin para Antigravity CLI
│   ├── plugin.json
│   └── skills/
│       ├── check-status.md
│       ├── fix-keyboard.md
│       ├── configure-gestures.md
│       └── configure-mouse.md
├── omp/                          # Skill para Oh My Pi (OMP)
│   └── skills/kde-wayland-suite/SKILL.md
└── opencode/                     # Skill para OpenCode
    └── skills/kde-wayland-suite/SKILL.md
```

---

## 🛡️ Segurança e Rollback

Todas as alterações gravam backups com timestamp em `~/.config/kde-config-backups/`. Para restaurar o estado anterior a qualquer momento:

```bash
make rollback
# ou
./bin/kde-config rollback
```
