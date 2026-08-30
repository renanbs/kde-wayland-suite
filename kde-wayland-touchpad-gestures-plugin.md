# KDE Wayland Touchpad Gestures — Portable AI Plugin (Expansível)

Este repositório contém uma estrutura portátil de plugin e skills para **Claude Code**, **Cursor**, **Antigravity CLI**, **OMP (Oh My Pi)** e **OpenCode**.

O objetivo é fornecer uma **skill** compartilhável e **comandos** para configurar e diagnosticar gestos de touchpad no **KDE Plasma (Wayland)** utilizando `libinput-gestures` e chamadas D-Bus do KWin via `qdbus6` / `qdbus`, detectando e contornando conflitos com os gestos nativos do KWin.

---

## Por que esta solução é necessária no KDE Plasma Wayland?

1. **Ausência de configuração gráfica no KWin**: No Plasma 6 / Wayland, o KWin possui alguns gestos 1:1 codificados internamente, mas a interface do sistema (KCM) não permite que o usuário mapeie livremente atalhos customizados ou escolha ações para 3 e 4 dedos.
2. **Conflito de eventos concorrentes**: Como o Wayland restringe injeção de eventos via X11 (`xdotool`), o `libinput-gestures` lê diretamente os eventos de hardware em `/dev/input/event*`. Tanto o KWin quanto o `libinput-gestures` recebem esses toques simultaneamente.
3. **Detecção de Conflitos e Duplicidade**: Se o KWin e o `libinput-gestures` tentarem executar a mesma ação (ex: abrir o Overview ao mesmo tempo), ocorrerá uma abertura dupla ou travamento de animação. A skill detecta essa concorrência e estrutura os dedos de forma complementar.
4. **Discrepância de executáveis D-Bus (`qdbus6` vs `qdbus`)**: No Arch Linux e distros derivadas recentes com Plasma 6, o executável se chama `qdbus6` e `qdbus` não existe no `PATH`. O plugin descobre dinamicamente o caminho exato.

---

## Estrutura de Diretórios do Repositório

```text
kde-wayland-touchpad-gestures/
├── README.md
├── shared/
│   ├── SKILL.md
│   ├── configure-kde-base.md
│   └── configure-kde-wayland-gestures.md
├── claude-code/
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── skills/
│   │   └── kde-wayland-touchpad-gestures/
│   │       └── SKILL.md
│   └── commands/
│       ├── configure-kde-base.md
│       └── configure-kde-wayland-gestures.md
├── cursor/
│   ├── skills/
│   │   └── kde-wayland-touchpad-gestures/
│   │       └── SKILL.md
│   └── commands/
│       ├── configure-kde-base.md
│       └── configure-kde-wayland-gestures.md
├── antigravity/
│   ├── plugin.json
│   └── skills/
│       ├── configure-kde-base.md
│       ├── configure-kde-wayland-gestures.md
│       └── kde-wayland-touchpad-gestures.md
├── omp/
│   └── skills/
│       └── kde-wayland-touchpad-gestures/
│           └── SKILL.md
└── opencode/
    └── skills/
        └── kde-wayland-touchpad-gestures/
            └── SKILL.md
```

- Os arquivos em `shared/` são a fonte canônica da verdade.
- Cada pasta de ferramenta (`claude-code/`, `cursor/`, `antigravity/`, `omp/`, `opencode/`) consome os templates canônicos no formato esperado por sua respectiva CLI.

---

## `shared/configure-kde-base.md`

```md
---
description: Detecta distribuição, versão do Plasma, sessão Wayland/X11, layout ativo de teclado, grupos de entrada e cliente D-Bus (qdbus6/qdbus). Pré-requisito para skills KDE.
---

# Configuração e Pré-Voo Base para KDE Plasma

Executa o diagnóstico completo do ambiente antes de aplicar qualquer alteração de atalhos ou gestos.

```bash
# 1. Sessão e Ambiente de Desktop
printf 'SESSION_TYPE=%s\n' "${XDG_SESSION_TYPE:-unknown}"
printf 'CURRENT_DESKTOP=%s\n' "${XDG_CURRENT_DESKTOP:-unknown}"

# 2. Detecção de Distribuição via os-release
if [ -f /etc/os-release ]; then
  . /etc/os-release
  DISTRO="${ID:-unknown}"
  DISTRO_LIKE="${ID_LIKE:-}"
else
  DISTRO="unknown"
  DISTRO_LIKE=""
fi
printf 'DISTRO=%s (LIKE=%s)\n' "$DISTRO" "$DISTRO_LIKE"
printf 'KERNEL=%s\n' "$(uname -r)"

# 3. Versão do KDE Plasma
if command -v kinfo >/dev/null 2>&1; then
  PLASMA_VER="$(kinfo 2>/dev/null | grep -i 'Plasma' | head -1 || true)"
elif command -v plasmashell >/dev/null 2>&1; then
  PLASMA_VER="$(plasmashell --version 2>&1 || true)"
else
  PLASMA_VER="unknown"
fi
printf 'PLASMA_VERSION=%s\n' "$PLASMA_VER"

# 4. Layout Ativo de Teclado
if command -v localectl >/dev/null 2>&1; then
  ACTIVE_LAYOUT="$(localectl status 2>/dev/null | grep -E "X11 (Layout|Model|Variant)" | tr '\n' ' ' || true)"
else
  ACTIVE_LAYOUT="localectl_unavailable"
fi
printf 'KEYBOARD_LAYOUT=%s\n' "$ACTIVE_LAYOUT"

# 5. Detecção Dinâmica de qdbus / qdbus6
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
printf 'QDBUS_CLIENT=%s\n' "$QDBUS"

# 6. Membrança do Grupo de Entrada (input)
if groups "$USER" | grep -qw "input"; then
  INPUT_GROUP_OK=true
else
  INPUT_GROUP_OK=false
fi
printf 'INPUT_GROUP_OK=%s\n' "$INPUT_GROUP_OK"

# 7. Detecção de Desktops Virtuais no KWin
if [ -n "$QDBUS" ]; then
  DESKTOPS_COUNT="$("$QDBUS" org.kde.KWin /KWin org.kde.KWin.virtualDesktopsCount 2>/dev/null || echo 'unknown')"
  printf 'KWIN_VIRTUAL_DESKTOPS=%s\n' "$DESKTOPS_COUNT"
fi
```

### Regras de Execução

1. Validar se a sessão é `wayland` e o desktop é `KDE` / `Plasma`.
2. Se `INPUT_GROUP_OK=false`, solicitar adição ao grupo `input` (`sudo usermod -aG input "$USER"`) e avisar que será necessário relogin para ler `/dev/input/event*`.
3. Se `QDBUS_CLIENT` estiver vazio, instalar as ferramentas Qt D-Bus adequadas para a distro (`qt6-tools` no Arch/Garuda/Manjaro, `qt6-tools-dev-tools` no Debian/Ubuntu, `qt6-qttools` no Fedora).
4. Guardar o caminho de `$QDBUS` para uso absoluto nos arquivos de configuração.
```

---

## `shared/SKILL.md`

```md
---
name: kde-wayland-touchpad-gestures
description: Configure, diagnose, repair, or remove custom touchpad swipe gestures on KDE Plasma Wayland (Plasma 5 & 6) using libinput-gestures and KWin shortcuts via qdbus6/qdbus. Detects and resolves conflicts with KWin native gestures and missing GUI touchpad options.
---

# KDE Plasma Wayland Touchpad Gestures

Configura gestos de deslize no touchpad usando `libinput-gestures` e aciona atalhos globais do KWin através do D-Bus (`qdbus6` / `qdbus`).

## Objetivos e Arquitetura

- **Contornar a limitação da GUI do KWin**: O KDE Plasma Wayland não fornece interface gráfica para associar gestos livres a atalhos arbitrários. Esta skill cria a camada de mapeamento via `libinput-gestures`.
- **Prevenção e Diagnóstico de Conflitos**: O KWin possui alguns gestos nativos embutidos (ex: swipe de 4 dedos para Overview ou troca de desktop). O `libinput-gestures` lê eventos concorrentes. A skill organiza os gestos para evitar acionamentos duplicados.
- **Portabilidade de D-Bus**: Descobre e fixa o caminho absoluto do cliente D-Bus (`qdbus6` no Arch/Garuda com Plasma 6, `qdbus` ou caminhos Qt6 específicos).
- **Sem dependência de xdotool no Wayland**: Evita `xdotool` para ações de desktop, impedindo erros e solicitações intrusivas de permissão de controle remoto do Wayland.
- **Segurança de Configuração**: Cria backups com timestamp em `$HOME/.config/` antes de qualquer edição.

---

## Diagnóstico e Pré-Voo

Execute os comandos não destrutivos abaixo para coletar o estado atual:

```bash
printf 'session=%s\n' "$XDG_SESSION_TYPE"
printf 'desktop=%s\n' "$XDG_CURRENT_DESKTOP"
command -v libinput-gestures || true
command -v qdbus6 || command -v qdbus || true
groups "$USER"
libinput-gestures-setup status 2>/dev/null || true
```

---

## Detecção de Conflitos com Gestos Nativos do KWin

No Plasma 6 (Wayland), o KWin escuta nativamente eventos de 3 e 4 dedos:
- Se o KWin já executa uma ação de 4 dedos (ex: abrir visão geral / Desktop Grid) e o `libinput-gestures` enviar outro comando para a mesma ação, o efeito será aberto e fechado instantaneamente (duplo disparo).
- **Estratégia Recomendada**:
  1. **3 Dedos (libinput-gestures)**: Ações frequentes de navegação de janelas e desktops:
     - `swipe up 3`: Overview (`invokeShortcut "Overview"`)
     - `swipe down 3`: Mostrar Área de Trabalho (`invokeShortcut "Show Desktop"`)
     - `swipe left 3`: Próximo Desktop Virtual (`invokeShortcut "Switch to Next Desktop"`)
     - `swipe right 3`: Desktop Virtual Anterior (`invokeShortcut "Switch to Previous Desktop"`)
  2. **4 Dedos (libinput-gestures)**: Gerenciamento de janelas ativas:
     - `swipe up 4`: Maximizar Janela (`invokeShortcut "Window Maximize"`)
     - `swipe down 4`: Minimizar Janela (`invokeShortcut "Window Minimize"`)
     - `swipe left 4`: Visualizar Janelas do Aplicativo (`invokeShortcut "Expose"`)
     - `swipe right 4`: Visualizar Todas as Janelas (`invokeShortcut "ExposeAll"`)

Se o usuário relatar que os gestos nativos do KWin estão colidindo:
- Teste em modo debug (`libinput-gestures -d`) para isolar se o KWin ou o daemon estão disparando o evento.
- Inspecione a configuração do KWin:
  ```bash
  kreadconfig6 --file kwinrc --group Touchpad --key Gestures 2>/dev/null || true
  ```

---

## Instalação de Pacotes

### 1. Arch Linux / Garuda / Manjaro

```bash
# Atualizar banco de dados e instalar daemon + utilitários
sudo pacman -S --needed libinput-gestures libinput qt6-tools wmctrl
```

### 2. Debian / Ubuntu

```bash
sudo apt-get update
sudo apt-get install -y libinput-gestures libinput-tools qdbus-qt6 qt6-tools-dev-tools wmctrl
```

### 3. Fedora

```bash
sudo dnf install -y libinput-gestures libinput-utils qt6-qttools wmctrl
```

### Permissão de Acesso ao Hardware (`/dev/input/*`)

O `libinput-gestures` precisa ler os dispositivos de toque:

```bash
if ! groups "$USER" | grep -qw "input"; then
  echo "Adicionando $USER ao grupo input..."
  sudo usermod -aG input "$USER"
  echo "ATENÇÃO: É obrigatório fazer LOGOUT e LOGIN novamente na sessão para aplicar as permissões de grupo."
fi
```

---

## Detecção Crítica do Binário D-Bus

Nunca use `qdbus` hardcoded. Descubra o caminho real:

```bash
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
  echo "Erro: Nenhum cliente qdbus foi encontrado. Instale as ferramentas D-Bus do Qt." >&2
  exit 1
fi
printf 'QDBUS selecionado: %s\n' "$QDBUS"
```

---

## Verificação dos Atalhos do KWin

Antes de escrever o arquivo de configuração, teste se os atalhos respondem corretamente via D-Bus:

```bash
# Overview / Visão Geral
"$QDBUS" org.kde.kglobalaccel /component/kwin invokeShortcut "Overview"

# Mostrar Área de Trabalho
"$QDBUS" org.kde.kglobalaccel /component/kwin invokeShortcut "Show Desktop"

# Alternar Desktops Virtuais
"$QDBUS" org.kde.kglobalaccel /component/kwin invokeShortcut "Switch to Next Desktop"
"$QDBUS" org.kde.kglobalaccel /component/kwin invokeShortcut "Switch to Previous Desktop"

# Maximizar / Minimizar
"$QDBUS" org.kde.kglobalaccel /component/kwin invokeShortcut "Window Maximize"
"$QDBUS" org.kde.kglobalaccel /component/kwin invokeShortcut "Window Minimize"
```

---

## Configuração do `libinput-gestures.conf`

1. **Backup seguro com timestamp**:
```bash
mkdir -p "$HOME/.config"
if [ -f "$HOME/.config/libinput-gestures.conf" ]; then
  BACKUP_FILE="$HOME/.config/libinput-gestures.conf.bak.$(date +%Y%m%d-%H%M%S)"
  cp -a "$HOME/.config/libinput-gestures.conf" "$BACKUP_FILE"
  printf 'Backup criado: %s\n' "$BACKUP_FILE"
fi
```

2. **Geração do arquivo com caminhos absolutos**:
```bash
cat > "$HOME/.config/libinput-gestures.conf" <<EOF
# Configurado pelo plugin KDE Wayland Touchpad Gestures
# Cliente D-Bus utilizado: $QDBUS

# ==========================================
# GESTOS DE 3 DEDOS (Navegação & Desktops)
# ==========================================
# Deslize para cima: Overview (Visão Geral)
gesture swipe up 3 $QDBUS org.kde.kglobalaccel /component/kwin invokeShortcut "Overview"

# Deslize para baixo: Mostrar Desktop
gesture swipe down 3 $QDBUS org.kde.kglobalaccel /component/kwin invokeShortcut "Show Desktop"

# Deslize para esquerda/direita: Troca de desktops virtuais
gesture swipe left 3 $QDBUS org.kde.kglobalaccel /component/kwin invokeShortcut "Switch to Next Desktop"
gesture swipe right 3 $QDBUS org.kde.kglobalaccel /component/kwin invokeShortcut "Switch to Previous Desktop"

# ==========================================
# GESTOS DE 4 DEDOS (Gerenciamento de Janelas)
# ==========================================
# Deslize para cima: Maximizar Janela Ativa
gesture swipe up 4 $QDBUS org.kde.kglobalaccel /component/kwin invokeShortcut "Window Maximize"

# Deslize para baixo: Minimizar Janela Ativa
gesture swipe down 4 $QDBUS org.kde.kglobalaccel /component/kwin invokeShortcut "Window Minimize"

# Deslize para esquerda/direita: Expose (Grade de Janelas)
gesture swipe left 4 $QDBUS org.kde.kglobalaccel /component/kwin invokeShortcut "Expose"
gesture swipe right 4 $QDBUS org.kde.kglobalaccel /component/kwin invokeShortcut "ExposeAll"
EOF
```

---

## Ativação do Serviço

```bash
libinput-gestures-setup autostart
libinput-gestures-setup restart
libinput-gestures-setup status
```

---

## Fluxo de Diagnóstico e Resolução de Problemas

Se os gestos não responderem:

1. **Parar o serviço em background**:
   ```bash
   libinput-gestures-setup stop
   ```
2. **Executar em modo debug (foreground)**:
   ```bash
   libinput-gestures -d
   ```
3. **Interpretação dos eventos**:
   - Se linhas como `GESTURE SWIPE up 3` aparecerem no terminal: o hardware e permissões de `input` estão OK. O problema está no atalho D-Bus ou no comando KWin.
   - Se nada aparecer ao tocar o touchpad: o usuário não está no grupo `input` ou não realizou logout/login após a alteração de grupo.
   - Se o KWin disparar a animação nativa junto com a do `libinput-gestures`: ocorre conflito de concorrência. Ajuste os dedos no `.conf` para usar a contagem de dedos não ocupada pelo KWin.
4. **Finalizar o teste**:
   Pressione `Ctrl+C` e reative o serviço normal:
   ```bash
   libinput-gestures-setup start
   libinput-gestures-setup status
   ```

---

## Checklist de Validação Final

- [ ] `$XDG_SESSION_TYPE` é `wayland` e ambiente é `KDE`/`Plasma`.
- [ ] Usuário pertence ao grupo `input` (`groups "$USER"`).
- [ ] Binário `$QDBUS` foi validado e inserido com caminho absoluto.
- [ ] Backup de `$HOME/.config/libinput-gestures.conf` foi realizado.
- [ ] Teste manual de 3 dedos: Cima (Overview), Baixo (Desktop), Lados (Desktops Virtuais).
- [ ] Teste manual de 4 dedos: Cima (Maximizar), Baixo (Minimizar).
- [ ] Sem conflitos visíveis de duplo acionamento com o KWin.
```

---

## `shared/configure-kde-wayland-gestures.md`

```md
---
description: Configura e diagnostica gestos de touchpad no KDE Plasma Wayland usando libinput-gestures e atalhos KWin via qdbus6/qdbus.
---

# Configurar Gestos de Touchpad no KDE Plasma Wayland

Configure gestos de touchpad nesta máquina seguindo a skill `kde-wayland-touchpad-gestures`.

### Fluxo de Execução:

1. **Pré-Voo e Diagnóstico**:
   - Verifique `session` (Wayland), `desktop` (KDE), status do `libinput-gestures` e grupos de entrada.
   - Detecte se o cliente D-Bus é `qdbus6`, `qdbus`, `qdbus-qt6` ou binário Qt6.
2. **Confirmação**:
   - Apresente o plano ao usuário antes de instalar pacotes ou modificar arquivos.
3. **Instalação e Permissões**:
   - Instale `libinput-gestures`, `libinput` e dependências Qt D-Bus.
   - Garanta que o usuário está no grupo `input`.
4. **Resolução de Conflitos com o KWin**:
   - Configure 3 dedos para navegação/desktops e 4 dedos para controle de janelas.
   - Evite `xdotool` para ações de desktop no Wayland.
5. **Configuração e Serviço**:
   - Crie backup em `$HOME/.config/libinput-gestures.conf.bak.<timestamp>`.
   - Grave `$HOME/.config/libinput-gestures.conf` com o `$QDBUS` absoluto detectado.
   - Execute `libinput-gestures-setup autostart` e `libinput-gestures-setup restart`.
6. **Verificação**:
   - Confirme `libinput-gestures-setup status`.
   - Oriente o usuário nos testes de 3 e 4 dedos e forneça o comando de debug (`libinput-gestures -d`) se necessário.
```

---

## Configuração Multiplataforma

### 1. Claude Code (`claude-code/`)

#### Estrutura:
```text
claude-code/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── kde-wayland-touchpad-gestures/
│       └── SKILL.md
└── commands/
    ├── configure-kde-base.md
    └── configure-kde-wayland-gestures.md
```

#### `claude-code/.claude-plugin/plugin.json`:
```json
{
  "name": "kde-wayland-touchpad-gestures",
  "version": "1.0.0",
  "description": "Configure and diagnose KDE Plasma Wayland touchpad gestures with libinput-gestures and KWin qdbus6/qdbus shortcuts.",
  "author": "Looptech"
}
```

#### Instalação no Claude Code:
Instale o diretório `claude-code/` como um plugin local do Claude Code. Os comandos ficam disponíveis como:
- `/kde-wayland-touchpad-gestures:configure-kde-wayland-gestures`
- `/kde-wayland-touchpad-gestures:configure-kde-base`

---

### 2. Cursor CLI / IDE (`cursor/`)

#### Estrutura:
```text
cursor/
├── skills/
│   └── kde-wayland-touchpad-gestures/
│       └── SKILL.md
└── commands/
    ├── configure-kde-base.md
    └── configure-kde-wayland-gestures.md
```

#### Instalação Global:
```bash
mkdir -p ~/.cursor/skills/kde-wayland-touchpad-gestures ~/.cursor/commands
cp shared/SKILL.md ~/.cursor/skills/kde-wayland-touchpad-gestures/SKILL.md
cp shared/configure-kde-base.md ~/.cursor/commands/configure-kde-base.md
cp shared/configure-kde-wayland-gestures.md ~/.cursor/commands/configure-kde-wayland-gestures.md
```

#### Invocação no Cursor:
```text
/configure-kde-wayland-gestures
```

---

### 3. Antigravity CLI (`antigravity/`)

#### Estrutura:
```text
antigravity/
├── plugin.json
└── skills/
    ├── configure-kde-base.md
    ├── configure-kde-wayland-gestures.md
    └── kde-wayland-touchpad-gestures.md
```

#### `antigravity/plugin.json`:
```json
{
  "name": "kde-wayland-touchpad-gestures",
  "version": "1.0.0",
  "description": "KDE Plasma Wayland touchpad gestures via libinput-gestures and KWin qdbus6/qdbus actions"
}
```

#### Instalação Local:
```bash
PLUGIN_ROOT="$HOME/.gemini/antigravity-cli/plugins/kde-wayland-touchpad-gestures"
mkdir -p "$PLUGIN_ROOT/skills"
cp antigravity/plugin.json "$PLUGIN_ROOT/plugin.json"
cp shared/SKILL.md "$PLUGIN_ROOT/skills/kde-wayland-touchpad-gestures.md"
cp shared/configure-kde-base.md "$PLUGIN_ROOT/skills/configure-kde-base.md"
cp shared/configure-kde-wayland-gestures.md "$PLUGIN_ROOT/skills/configure-kde-wayland-gestures.md"
```

---

### 4. OMP (Oh My Pi) (`omp/`)

#### Estrutura:
```text
omp/
└── skills/
    └── kde-wayland-touchpad-gestures/
        └── SKILL.md
```

#### Instalação Local / Global:
```bash
# Global
mkdir -p ~/.omp/skills/kde-wayland-touchpad-gestures
cp shared/SKILL.md ~/.omp/skills/kde-wayland-touchpad-gestures/SKILL.md

# Ou por projeto
mkdir -p .omp/skills/kde-wayland-touchpad-gestures
cp shared/SKILL.md .omp/skills/kde-wayland-touchpad-gestures/SKILL.md
```

---

### 5. OpenCode (`opencode/`)

#### Estrutura:
```text
opencode/
└── skills/
    └── kde-wayland-touchpad-gestures/
        └── SKILL.md
```

#### Instalação Local:
```bash
mkdir -p ~/.config/opencode/skills/kde-wayland-touchpad-gestures
cp shared/SKILL.md ~/.config/opencode/skills/kde-wayland-touchpad-gestures/SKILL.md
```

---

## Resumo das Correções Aplicadas

1. **Detecção e Resolução de Conflitos**: Documentação clara e mapeamento inteligente (3 dedos para desktop/overview e 4 dedos para controle de janelas) para evitar colisões com gestos nativos do KWin.
2. **Scripts de Detecção Robustos**:
   - Distro detectada via `/etc/os-release`.
   - Layout de teclado ativo obtido via `localectl status`.
   - Tratamento de permissões do grupo `input` com alerta explícito de logout/login.
3. **Remoção de Duplicidades e Inconsistências**:
   - Seção do Cursor CLI desduplicada.
   - Plataformas (`claude-code/`, `cursor/`, `antigravity/`, `omp/`, `opencode/`) separadas corretamente na raiz da arquitetura.
   - Referências quebradas removidas e templates consolidados em `shared/`.
4. **Sintaxe Segura de Shell**:
   - Uso consistente de `$HOME` e aspas seguras em operações de backup e criação de configuração.
