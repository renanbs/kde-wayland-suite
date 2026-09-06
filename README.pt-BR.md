# KDE Plasma 6 Wayland Suite: Entrada, Hardware e Reparo de Teclado

[![Idioma: Inglês](https://img.shields.io/badge/Language-English-blue.svg)](README.md)
[![Idioma: Português](https://img.shields.io/badge/Idioma-Portugu%C3%AAs%20do%20Brasil-green.svg)](README.pt-BR.md)
[![KDE Plasma 6](https://img.shields.io/badge/KDE%20Plasma-6-blue.svg)](https://kde.org/plasma-desktop/)
[![Wayland Ready](https://img.shields.io/badge/Wayland-Native-success.svg)](https://wayland.freedesktop.org/)
[![Multi-Harness Plugin](https://img.shields.io/badge/AI%20Harnesses-OMP%20%7C%20Claude%20%7C%20Cursor%20%7C%20Antigravity%20%7C%20OpenCode-purple.svg)](#-instalação-e-integração-com-ferramentas-de-ia)
[![Versão](https://img.shields.io/badge/Vers%C3%A3o-1.8.1-brightgreen.svg)](package.json)

**[English](README.md)** | **[Português do Brasil](README.pt-BR.md)**

Uma suíte de automação portátil, kit de diagnósticos e plugin multi-agente de IA para o **KDE Plasma 6 (Wayland)**. Projetada para corrigir atalhos corrompidos, resolver teclas modificadoras mortas em laptops Tongfang/Avell, gerenciar a energia do teclado de forma dinâmica, configurar a cedilha nativa (`ç`) no layout US-intl sem depender de input methods, eliminar travamentos de clipboard no Wayland, configurar gestos de 3 e 4 dedos no touchpad, mapear mouses Logitech MX Master 3S e auditar o consumo de bateria.

Compatível como plugin nativo para **Oh My Pi (OMP)**, **Claude Code**, **Cursor IDE & CLI**, **Google Antigravity** e **OpenCode**, além de funcionar diretamente pelo terminal via CLI (`kde-config`) e `Makefile`.

---

## 🎯 Problemas Resolvidos e Funcionalidades

### 1. Desbloqueio de Matriz de Teclado em Laptops Tongfang / Avell / Clevo
* **Problema:** Em notebooks com chassi Tongfang (Avell A62 LIV, GK5, GM5, Tuxedo Pulse, Schenker), a tecla `Left Ctrl` física não gera nenhum evento de entrada no `evtest`/`xev` porque o driver `i8042` e o DSDT ACPI do Linux descartam pacotes da porta I/O `0x60`.
* **Solução:** `./bin/kde-config fix-tongfang` injeta `i8042.nopnp=1 i8042.nomux=1 i8042.reset=1 atkbd.reset=1 acpi_osi='Windows 2020'` no GRUB, desbloqueando a matriz completa.

### 2. Gerenciamento Inteligente de Energia do Teclado (`anti-latch`)
* **Problema:** Sob o Runtime Power Management do Linux, o barramento PS/2 `serio0` entra em suspensão ociosa (`power/control = auto`), fazendo com que o primeiro pressionamento de modificadores de byte único (`Left Ctrl`) sofra atraso para acordar a porta.
* **Solução:** `./bin/kde-config smart-keyboard-power --apply` instala uma regra udev dinâmica que mantém o barramento em `power/control = on` (zero latência) quando o notebook é usado sozinho, e alterna automaticamente para `auto` (economia de bateria) sempre que um teclado externo USB ou Bluetooth for conectado.

### 3. Atalhos `Ctrl+C` / `Ctrl+<tecla>` Quebrados no Layout ABNT2 (`br`)
* **Problema:** Módulos legados de input method (`GTK_IM_MODULE=cedilla` / `QT_IM_MODULE=cedilla`) ou o `fcitx5` ativo sob Wayland fazem *grab* do teclado e engolem combinações com Ctrl em apps Qt, GTK e Electron.
* **Solução:** Elimina variáveis nocivas de IM e mascara o autostart do `fcitx5` no sistema.

### 4. Cedilha Nativa no Layout US-intl (`' + c` $\to$ `ç` em Chrome, Orca IDE, Electron, GTK, Qt)
* **Problema:** A tabela padrão `en_US` mapeia `<dead_acute> <c>` para `ć` (c com agudo).
* **Solução:** Composição nativa **sem nenhum input method**. A tabela pt_BR do sistema (`/usr/share/X11/locale/pt_BR.UTF-8/Compose`) já mapeia `<dead_acute> <c>` para `ç`. A suite configura `LC_CTYPE=pt_BR.UTF-8` em `~/.config/environment.d/cedilla.conf` e injeta `--ozone-platform-hint=auto` nas flags dos navegadores.

### 5. Reparo de Deadlocks de Clipboard no Wayland
* **Problema:** Processos zumbis do `xsel` congelam comandos de cópia e colagem no terminal.
* **Solução:** Elimina processos travados e assegura o funcionamento nativo do backend `wl-clipboard` (`wl-copy`/`wl-paste`).

### 6. Gestos de Touchpad de 3 e 4 Dedos sem Conflito
* **Solução:** Mapeia gestos de 3 dedos (troca de workspace, Overview) e 4 dedos complementares às animações 1:1 nativas do KWin via `libinput-gestures` e KWin D-Bus (`qdbus6`).

### 7. Configuração de Botões e Rolagem do Logitech MX Master 3S
* **Solução:** Instala o `logiops`, configura o botão de polegar para Grade de Telas e Overview, fixa o SmartShift em rolagem livre e habilita `PerOutputVirtualDesktops=true` para setups multi-monitor.

### 8. Diagnóstico de Bateria e GPU Híbrida
* **Solução:** Audita a GPU primária do compositor em laptops híbridos Intel/NVIDIA/AMD, políticas de PCIe ASPM, runtime PM de dispositivos PCI e a saúde da bateria (`battery-status`).

### 9. Detecção de Host de IA (Harness) e Perfil de Modelos
* **Solução:** Detecta automaticamente o host ativo (OMP, Claude Code, Cursor, Antigravity), mapeia os papéis de modelos (Raciocínio, Código, Revisão, Segurança) e audita o alinhamento do ambiente em tempo real.

### 10. Motor de Relatórios Numerados e Interativos
* **Solução:** Registros estruturados salvos em `~/.local/state/kde-wayland-suite/runs/`. Permite seleção interativa (`report --select`), consulta indexada (`report 3`) e gera ações recomendadas de 1 linha para qualquer aviso ou falha.

---

## 🚀 Uso Rápido (CLI e Makefile)

```bash
# Clonar o repositório
git clone https://github.com/renanbs/kde-wayland-suite.git ~/src/kde-wayland-suite
cd ~/src/kde-wayland-suite

# Instalar o comando global 'kde-config' em ~/.local/bin
make install-cli

# Auditoria de saúde geral do ambiente
./bin/kde-config status
# ou: make status

# Inicialização guiada completa com backup automático
./bin/kde-config init
```

---

## 🛠️ Tabela Geral de Comandos da CLI

| Comando | Alvo Makefile | Descrição |
| :--- | :--- | :--- |
| `kde-config status` | `make status` | Auditoria unificada em 6 etapas: hardware, DMI, energia, IM, cedilha e gestos |
| `kde-config init` | `make init` | Inicialização guiada completa com fluxo de perguntas e backup automático |
| `kde-config fix-keyboard` | `make fix-keyboard` | Corrige `Ctrl+C` no ABNT2, configura a cedilha nativa e mascara o fcitx5 |
| `kde-config fix-tongfang` | `make fix-tongfang` | Desbloqueia a matriz no GRUB para laptops Tongfang/Avell/Clevo |
| `kde-config smart-keyboard-power` | `make smart-keyboard-power` | Gestão dinâmica de energia (`on` sozinho, `auto` com teclado USB/BT) |
| `kde-config configure-harness` | — | Configura e sincroniza o perfil do host de IA e papéis de modelos |
| `kde-config battery-status` | `make battery-status` | Diagnóstico de bateria, GPU híbrida e PCIe ASPM (somente leitura) |
| `kde-config battery-apply` | `make battery-apply` | Aplica otimizações de bateria escolhidas pelo usuário (`BATTERY_FIX_*`) |
| `kde-config gestures` | `make gestures` | Configura gestos de 3 e 4 dedos no touchpad (`libinput-gestures`) |
| `kde-config mouse` | `make mouse` | Configura botão de polegar e SmartShift do Logitech MX Master 3S via `logiops` |
| `kde-config test-keyboard` | `make test-keyboard` | Monitor interativo de eventos de teclado em tempo real (`/dev/input/eventX`) |
| `kde-config monitor-irq` | `make monitor-irq` | Monitor elétrico de hardware no IRQ 1 (`i8042`) |
| `kde-config switch [br\|us]` | `make switch-br` | Alterna o layout ativo no KWin via D-Bus (0=br abnt2, 1=us alt-intl) |
| `kde-config report` | `make report` | Exibe o relatório da última execução, métricas e ações recomendadas |
| `kde-config report --list` | — | Lista os relatórios recentes numerados (`[1..N]`) |
| `kde-config report <N>` | — | Exibe detalhadamente o N-ésimo relatório mais recente |
| `kde-config report --select` | — | Menu interativo no terminal para escolher qualquer relatório |
| `kde-config upgrade` | `make upgrade` | Verifica e aplica atualizações do GitHub e marketplace |
| `kde-config rollback` | `make rollback` | Restaura o snapshot anterior a partir do backup |
| `kde-config help` | `make help` | Exibe o manual completo de ajuda |

---

## 🤖 Instalação e Integração com Ferramentas de IA

### 1. Oh My Pi (OMP)
Instale diretamente pelo marketplace remoto:
```bash
# No terminal do OMP:
omp plugin marketplace add renanbs/kde-wayland-suite
omp plugin install kde-wayland-suite@kde-wayland-suite

# Atualizar versão:
omp plugin upgrade kde-wayland-suite@kde-wayland-suite
```
* **Comandos Slash Disponíveis:** `/kde-wayland-suite:status`, `/kde-wayland-suite:init`, `/kde-wayland-suite:fix-keyboard`, `/kde-wayland-suite:fix-tongfang`, `/kde-wayland-suite:smart-keyboard-power`, `/kde-wayland-suite:configure-harness`, `/kde-wayland-suite:battery`, `/kde-wayland-suite:report`, `/kde-wayland-suite:help`, `/kde-wayland-suite:upgrade`.
* **Skills:** `skill://kde-wayland-suite`, `skill://kde-wayland-suite-architecture`.

### 2. Claude Code
```bash
/plugin marketplace add renanbs/kde-wayland-suite
/plugin install kde-wayland-suite@kde-wayland-suite
```

### 3. Cursor IDE & Agent
```bash
# 1. Instalar CLI global
cd ~/src/kde-wayland-suite && make install-cli

# 2. Habilitar regras globais para todos os projetos no Cursor
mkdir -p ~/.cursor/rules
cp .cursor/rules/kde-wayland-suite.mdc ~/.cursor/rules/
```

### 4. Google Antigravity & OpenCode
Reconhecido automaticamente pela raiz do workspace via `antigravity/plugin.json` e `opencode/skills/`.

---

## 📐 Arquitetura e Disciplina de Engenharia

Este repositório segue a constituição arquitetural definida em **`skills/kde-wayland-suite-architecture`**:
1. **Fonte Canônica em `base/`:** Todos os comandos `.md` residem em `base/commands/`, scripts em `base/shared/` e skills em `base/skills/`. Todas as pastas de plataforma usam symlinks relativos.
2. **Contrato de Saída Tetra-Fásico (`OUTPUT-CONTRACT.md`):** Todo comando executado por IAs segue rigorosamente:
   * `### 1. Plano` (Comando, Faz, Reversível)
   * `### 2. Execução` (`✅`, `⏭️`, `⚠️`, `❌`)
   * `### 3. Resumo` (Tabela: O que mudou, O que não mudou, Backup, Relatório salvo, Reverter, Requer)
   * `### 4. Ações Recomendadas` (Obrigatório se houver `⚠️` ou `❌`, com comando de 1 linha)
3. **Eventos Estruturados:** Salvos em `~/.local/state/kde-wayland-suite/runs/<data_hora>-<cmd>/events.tsv`.

---

## 📄 Licença

MIT © [Renan BS](https://github.com/renanbs)
