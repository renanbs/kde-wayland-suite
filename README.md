# KDE Wayland Suite: Keyboard Layout, Shortcuts & Gestures

[![KDE Plasma 6](https://img.shields.io/badge/KDE%20Plasma-6-blue.svg)](https://kde.org/plasma-desktop/)
[![Wayland Ready](https://img.shields.io/badge/Wayland-Native-success.svg)](https://wayland.freedesktop.org/)
[![Multi-Harness Plugin](https://img.shields.io/badge/AI%20Harnesses-Claude%20%7C%20Cursor%20%7C%20Antigravity%20%7C%20OMP%20%7C%20OpenCode-purple.svg)](#-passo-a-passo-por-ferramenta-de-ia)

Plugin e suíte de automação portátil para **KDE Plasma 6 (Wayland)** projetado para corrigir problemas de atalhos e gerenciar toda a pilha de entrada no Linux — cobrindo **teclado**, **atalhos** e **gestos de touchpad** sem concorrência com o KWin.

Compatível com **Claude Code**, **Cursor IDE & CLI**, **Antigravity CLI**, **OMP (Oh My Pi)** e **OpenCode**, além de funcionar diretamente pelo terminal via CLI (`kde-config`) ou `Makefile`.

---

## 🎯 Problemas Resolvidos

1. **`Ctrl+C` quebrado no layout ABNT2 (`br`)**:
   - **Causa**: Módulos legados `GTK_IM_MODULE=cedilla` / `QT_IM_MODULE=cedilla` em `~/.config/environment.d/im.conf` interceptavam a tecla `C` em baixo nível e suprimiam modificadores no Wayland.
   - **Solução**: Remoção limpa das variáveis nocivas de IM e recarregamento a quente via KWin.
2. **Cedilha no layout US-intl (`' + c` $\to$ `ç`)**:
   - **Solução**: Configuração nativa de `~/.XCompose` lido automaticamente pelo `libxkbcommon` (Wayland/Qt/GTK/Electron) sem a necessidade de módulos IM.
3. **Gestos de Touchpad sem Conflito**:
   - **Solução**: Mapeamento de 3 e 4 dedos complementares às animações 1:1 nativas do KWin via `libinput-gestures` e D-Bus (`qdbus6`).
4. **Gerenciamento de Layouts no Plasma 6**:
   - Atualização atômica de `~/.config/kxkbrc` com `kwriteconfig6 --notify` e alternância via D-Bus (`org.kde.keyboard /Layouts`).

---

## 🚀 Passo a Passo de Uso

### 1. Uso Direto pelo Terminal

#### Via Makefile
```bash
# Auditoria de saúde do sistema (sessão, teclado, IM e gestos)
make check
# ou: make status

# Aplicar correção de Ctrl+C no ABNT2 e suporte a cedilha no US-intl
make fix-keyboard

# Configurar gestos de 3 e 4 dedos no touchpad
make gestures

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
./bin/kde-config status           # Auditoria completa
./bin/kde-config fix-keyboard     # Corrige atalhos e teclado
./bin/kde-config gestures         # Configura gestos de touchpad
./bin/kde-config switch [br|us]   # Alterna layout via D-Bus
./bin/kde-config shortcut-switch  # Ativa atalho Meta+Space
./bin/kde-config rollback         # Restaura último backup
```

---

## 🤖 Passo a Passo por Ferramenta de IA

### 1. Claude Code
O Claude Code carrega o plugin automaticamente através do manifesto `.claude-plugin/plugin.json`:
* **Comandos de Barra (Slash Commands)**:
  * `/check-status` — Executa o diagnóstico completo do ambiente.
  * `/fix-keyboard` — Executa a correção atômica de teclado e atalhos.
  * `/configure-gestures` — Configura e inicia o daemon de gestos.
* **Ativação por Linguagem Natural**: Basta pedir ao Claude (ex: *"arrume meus atalhos no KDE Wayland"* ou *"verifique o status do teclado"*), e a skill `kde-wayland-suite` será disparada.

### 2. Cursor (IDE & Cursor CLI)
O Cursor consome a suíte tanto via editor visual quanto via **Cursor CLI** (`cursor agent` / headless mode):
* **Cursor Rules (`.cursor/rules/kde-wayland-suite.mdc`)**: Regra em formato MDC com ativação contínua (`alwaysApply: true`), permitindo que o Cursor CLI e o Agent compreendam o contexto e executem `./bin/kde-config` ou comandos do `Makefile`.
* **Compatibilidade Clássica (`.cursorrules`)**: Arquivo de regras na raiz para indexadores de CLI que não leem a pasta `.cursor`.
* **Comandos e Skills (`cursor/commands/` e `cursor/skills/`)**: Mapeamento direto de slash commands e skills para o Composer/Chat.

### 3. Antigravity CLI
* O arquivo `antigravity/plugin.json` registra as capabilities e aponta para as skills em `antigravity/skills/`:
  * `check-status.md`
  * `fix-keyboard.md`
  * `configure-gestures.md`
* Ao solicitar qualquer operação de KDE/Wayland, o Antigravity carrega a skill correspondente e executa os scripts canônicos em `shared/`.

### 4. OMP (Oh My Pi)
* Consome nativamente a skill em `omp/skills/kde-wayland-suite/SKILL.md`.
* Pode ser referenciada ou inspecionada via `skill://kde-wayland-suite`.

### 5. OpenCode
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
│   └── preflight-base.sh
├── claude-code/                  # Plugin para Claude Code
│   ├── .claude-plugin/plugin.json
│   ├── skills/kde-wayland-suite/SKILL.md
│   └── commands/
│       ├── check-status.md
│       ├── fix-keyboard.md
│       └── configure-gestures.md
├── cursor/                       # Plugin e Rules para Cursor IDE
│   ├── skills/kde-wayland-suite/SKILL.md
│   └── commands/
│       ├── check-status.md
│       └── fix-keyboard.md
├── antigravity/                  # Plugin para Antigravity CLI
│   ├── plugin.json
│   └── skills/
│       ├── check-status.md
│       ├── fix-keyboard.md
│       └── configure-gestures.md
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
