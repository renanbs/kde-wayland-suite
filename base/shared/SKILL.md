---
name: kde-wayland-suite
description: Comprehensive KDE Plasma 6 Wayland configuration suite for keyboard shortcuts (Ctrl+C ABNT2 fix), cedilla on US-intl (Chrome, Orca IDE, Electron, GTK, Qt via LC_CTYPE, XCompose & Wayland IME flags), Wayland clipboard repair (wl-clipboard/xsel deadlock fix), 3/4-finger touchpad gestures using libinput-gestures and KWin D-Bus, and Logitech MX Master 3S button/scroll configuration via logiops.
---

# KDE Plasma 6 Wayland Suite (Keyboard, Shortcuts & Gestures)

Esta skill fornece automações e diagnósticos para resolver problemas comuns na pilha de entrada e clipboard do **KDE Plasma 6 (Wayland)**:

1. **Correção de Atalhos de Teclado (`Ctrl+C` no ABNT2)**: Elimina o módulo legado `im-cedilla` que sequestra eventos de teclas e quebra o `Ctrl+C` sob Wayland.
2. **Suporte a Cedilha no US-intl (`' + c` $\to$ `ç` em Chrome, Orca IDE, Electron, GTK, Qt)**:
   - Configura `LC_CTYPE=pt_BR.UTF-8` em `~/.config/environment.d/cedilla.conf` e `systemd --user` para usar a tabela nativa de composição pt_BR.
   - Configura `~/.XCompose` e `XCOMPOSEFILE` com regras completas de cedilha (`<dead_acute> <c> : "ç"`).
   - Injeta flags de Wayland IME (`--enable-wayland-ime`, `--ozone-platform-hint=auto`) em `~/.config/chrome-flags.conf`, `~/.config/chromium-flags.conf`, `~/.config/orca-flags.conf`, `~/.config/code-flags.conf` e `~/.config/electron*-flags.conf`.
3. **Desbloqueio de Clipboard no Terminal (`Ctrl+Shift+V` / Imagens)**: Mata processos `xsel` travados e assegura a presença do `wl-clipboard` para suporte nativo a cópia e colagem de texto/imagens no Konsole e Fish Shell.
4. **Gestos de Touchpad Portáveis**: Mapeia gestos de 3 e 4 dedos complementares ao KWin via `libinput-gestures` e D-Bus (`qdbus6`), sem conflitos de concorrência com gestos nativos do Plasma.
5. **Diagnóstico e Verificação Geral**: Executa auditoria em tempo real da sessão, layouts ativos, estado do clipboard, flags de navegadores, validação de composição e estado dos daemons.
6. **Logitech MX Master 3S (`logiops`/`logid`)**: Instala o `logiops`, gera `~/.config/logid.cfg` (linkado em `/etc/logid.cfg`, editável sem sudo) mapeando o botão de gesto para troca de workspace/Overview/Mostrar Área de Trabalho e fixando o SmartShift em rolagem livre. Também habilita `kwinrc [Windows] PerOutputVirtualDesktops=true` para a troca de workspace refletir corretamente em setups multi-monitor.
7. **Diagnóstico e Correção de Bateria/Energia**: `diagnose-battery.sh` audita GPU primária do compositor em sistemas híbridos Intel/NVIDIA/AMD (detecta se o KWin compõe numa GPU diferente da que atende o painel interno, mantendo a GPU discreta sempre ligada à toa), política de PCIe ASPM, saúde da bateria, rádios ociosos (Bluetooth/Docker) e governor de CPU — somente leitura. `configure-battery.sh` aplica só as correções escolhidas pelo usuário (`BATTERY_FIX_GPU_PRIMARY`, `BATTERY_FIX_PCIE_ASPM`, `BATTERY_FIX_PCIE_ASPM_PERSIST`), sempre criando um snapshot de reversão; `revert-battery.sh` desfaz a última aplicação.
8. **Detecção do bug de colapso do `kxkbrc` (KWin/Plasma)**: `check-status.sh` detecta quando o Plasma regravou `~/.config/kxkbrc` mantendo só o layout que estava ativo no momento do logout, descartando o resto da `LayoutList` (bug conhecido do KWin/Plasma, não causado por esta suite — sintoma típico: o widget de troca de layout some da barra de tarefas após reiniciar). `fix-keyboard.sh` corrige o estado na hora; opcionalmente pode instalar um autostart que reaplica o layout completo a cada login, para o bug não voltar a cada reboot.

> **Importante para agentes de IA**: a auto-cura do layout no login (`KDE_SUITE_LAYOUT_AUTOHEAL=1`) **não deve ser habilitada automaticamente** — ela adiciona uma entrada de autostart à sessão do usuário. Ao rodar `fix-keyboard` (direto ou via `init`), pergunte ao usuário se ele quer habilitar essa auto-cura (explicando o bug e o trade-off de ter mais uma entrada de autostart) antes de definir a variável de ambiente. Se ele recusar ou não responder, rode sem a variável — o comando continua corrigindo o estado atual do `kxkbrc` normalmente, só não instala o autostart.

---

## Fluxo Guiado de `init` (obrigatório para agentes de IA)

`init` configura várias coisas de uma vez (teclado, gestos, mouse, atalhos). **Nunca rode `init` de forma cega.** Antes de executar qualquer comando, use a ferramenta `AskUserQuestion` para coletar todas as escolhas do usuário de uma vez só (uma única chamada, múltiplas perguntas), e só então rode `./bin/kde-config init` com as variáveis de ambiente correspondentes. Não pergunte no meio da execução — colete tudo antes.

Pergunta 1 — **Componentes** (multiSelect, todos pré-selecionáveis como recomendados):
- "Teclado, cedilha e atalhos (Ctrl+C ABNT2)" — correção de atalhos, cedilha no US-intl, clipboard Wayland. Recomendado.
- "Gestos de touchpad (3/4 dedos)" — libinput-gestures + KWin. Recomendado se houver touchpad.
- "Mouse Logitech MX Master 3S (logiops)" — só relevante se o usuário tiver esse mouse.
- "Diagnóstico de bateria/energia" — recomendado. Só roda o diagnóstico (`battery-status`) dentro do `init`; nenhuma correção é aplicada nessa etapa.

Pergunta 2 — **Auto-cura do layout no login** (single-select): "Sim, proteger contra o bug do KWin/Plasma (recomendado)" vs. "Não, prefiro corrigir manualmente se acontecer" — explique brevemente o bug (Plasma pode colapsar `~/.config/kxkbrc` para um único layout ao reiniciar) e o trade-off (adiciona uma entrada de autostart).

Mapeamento das respostas para a execução:

```bash
# Exemplo: usuário não tem o mouse, quer os outros componentes e quer a auto-cura
SKIP_MOUSE=1 KDE_SUITE_LAYOUT_AUTOHEAL=1 ./bin/kde-config init

# Exemplo: usuário só quer teclado/cedilha
SKIP_GESTURES=1 SKIP_MOUSE=1 SKIP_BATTERY=1 ./bin/kde-config init
```

Se o usuário pedir para configurar só uma coisa específica (ex: "só o mouse"), pule o fluxo de perguntas do `init` e rode o comando específico diretamente (`./bin/kde-config mouse`, etc.) — o fluxo guiado acima é para quando o usuário pede para "inicializar"/"configurar tudo"/`init`.

### Bateria: diagnóstico dentro do `init`, correção fora dele

`init` só roda `battery-status` (leitura). **Nunca passe `BATTERY_FIX_*` durante o `init`** — depois que o diagnóstico aparecer na saída, explique cada achado ao usuário e use `AskUserQuestion` para decidir o que aplicar (achado por achado), só então rodando `./bin/kde-config battery-apply` com as variáveis correspondentes. Ver seção "Diagnóstico e Correção de Bateria/Energia" acima para os trade-offs de cada correção. `battery-revert` desfaz a última aplicação.

**Sempre perguntar antes de aplicar, sempre informar depois.** Isso vale para toda correção de bateria/energia (GPU primária, ASPM, e a persistência do ASPM via `BATTERY_FIX_PCIE_ASPM_PERSIST`), não só a primeira execução — mesmo re-aplicar ou reverter exige confirmação prévia via `AskUserQuestion`, nunca rode `battery-apply`/`battery-revert` por conta própria só porque um diagnóstico anterior sugeriu isso. Depois de cada `battery-apply` ou `battery-revert`, sempre resuma pro usuário o que de fato mudou (ou "nada mudou, já estava correto"), onde ficou o snapshot de reversão, e se o efeito exige logout/login ou reboot para valer. `BATTERY_FIX_PCIE_ASPM` chama `sudo` internamente; em ambientes sem TTY (ex: sessão de agente sandboxed) o `sudo` falha silenciosamente pedindo senha — nesse caso, informe o usuário e peça para ele rodar o comando com o prefixo `!` no próprio terminal em vez de tentar contornar com `--no-verify`/reautenticação.

---

## Comandos Disponíveis

| Comando | Descrição |
| :--- | :--- |
| `shared/check-status.sh` | Auditoria completa de ambiente, teclado, cedilha (Chrome/Orca), clipboard Wayland, variáveis IM e gestos |
| `shared/fix-keyboard.sh` | Correção de `Ctrl+C`, cedilha no US-intl (Chrome, Orca, Electron), deadlock de clipboard e recarregamento via KWin |
| `shared/configure-gestures.sh` | Setup de `libinput-gestures.conf` e reinício de serviço |
| `shared/configure-mouse.sh` | Instala `logiops` e configura o MX Master 3S (botão de gesto, SmartShift) |
| `shared/diagnose-battery.sh` | Diagnóstico de bateria/energia: GPU primária, PCIe ASPM, saúde da bateria, rádios (só leitura) |
| `shared/configure-battery.sh` | Aplica correções de bateria decididas via `BATTERY_FIX_*`, com backup automático |
| `shared/revert-battery.sh` | Reverte a última aplicação de `configure-battery.sh` (ou um snapshot específico) |
| `shared/preflight-base.sh` | Pré-voo de ambiente, versão do Plasma e caminho do `qdbus6` |
| `bin/kde-config switch [br\|us]` | Alternância imediata de layout de teclado via D-Bus |

---

## Uso Rápido via CLI

```bash
# Diagnóstico completo
./bin/kde-config status

# Aplicar correção de teclado, cedilha (Chrome/Orca) e clipboard
./bin/kde-config fix-keyboard

# Aplicar configuração de gestos
./bin/kde-config gestures

# Configurar o mouse Logitech MX Master 3S
./bin/kde-config mouse

# Diagnóstico de bateria/energia (só leitura)
./bin/kde-config battery-status

# Aplicar correção escolhida (nunca sem antes perguntar ao usuário)
BATTERY_FIX_GPU_PRIMARY=1 ./bin/kde-config battery-apply

# Reverter a última aplicação
./bin/kde-config battery-revert

# Alternar layout ativo
./bin/kde-config switch br
./bin/kde-config switch us
```
