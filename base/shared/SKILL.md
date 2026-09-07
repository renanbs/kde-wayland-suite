---
name: linux-wayland-suite
description: Comprehensive Linux Wayland configuration suite for KDE Plasma, GNOME, and multi-vendor hardware: keyboard shortcuts repair, Tongfang/Avell/Clevo matrix unlocking, smart dynamic keyboard power management, native cedilla on US-intl via the native pt_BR compose table (LC_CTYPE, no input method), Wayland clipboard repair, 3/4-finger touchpad gestures, Logitech MX Master 3S button/scroll configuration via logiops, and battery/power diagnostics.
---

# Linux Wayland Suite (Input, Hardware & Desktop Automation)
Esta skill fornece automações e diagnósticos para resolver problemas comuns na pilha de entrada e clipboard do **KDE Plasma 6 (Wayland)**:

1. **Correção de Atalhos de Teclado (`Ctrl+C` no ABNT2)**: Elimina o módulo legado `im-cedilla` que sequestra eventos de teclas e quebra o `Ctrl+C` sob Wayland.
2. **Suporte a Cedilha no US-intl (`dead_acute + c` $\to$ `ç` em Chrome, Orca IDE, Electron, GTK, Qt)**: feito **sem nenhum input method**. A tabela de composição do sistema para pt_BR (`/usr/share/X11/locale/pt_BR.UTF-8/Compose`) já mapeia `<dead_acute> <c>` para `ç` nativamente — é exatamente para isso que ela existe. O único requisito é que o processo do app tenha `LC_CTYPE=pt_BR.UTF-8`, senão o `libxkbcommon` escolhe a tabela `en_US`, que mapeia a mesma sequência para `ć` (c com agudo). A suite grava `LC_CTYPE=pt_BR.UTF-8` em `~/.config/environment.d/cedilla.conf` (+ `systemd --user set-environment` e `~/.config/fish/conf.d/cedilla.fish`), e injeta `--ozone-platform-hint=auto` nos `*-flags.conf` de Chrome/Chromium/Brave/Orca/Code/Electron. **Só vale para processos iniciados após o login** — apps já abertos mantêm o ambiente antigo, então é preciso logout/login para a sessão inteira herdar o locale.
   > Não usamos mais `~/.XCompose` nem `--enable-wayland-ime`: as regras do `~/.XCompose` que a suite escrevia eram duplicatas exatas da tabela pt_BR e o `libxkbcommon` as descartava (`this compose sequence is a duplicate of another; skipping line` no journal), e a flag de IME só serve para conversar com um input method, que não usamos mais.
3. **Desbloqueio de Clipboard no Terminal (`Ctrl+Shift+V` / Imagens)**: Mata processos `xsel` travados e assegura a presença do `wl-clipboard` para suporte nativo a cópia e colagem de texto/imagens no Konsole e Fish Shell.
4. **Gestos de Touchpad Portáveis**: Mapeia gestos de 3 e 4 dedos complementares ao KWin via `libinput-gestures` e D-Bus (`qdbus6`), sem conflitos de concorrência com gestos nativos do Plasma.
5. **Diagnóstico e Verificação Geral**: Executa auditoria em tempo real da sessão, layouts ativos, estado do clipboard, flags de navegadores, validação de composição e estado dos daemons.
6. **Logitech MX Master 3S (`logiops`/`logid`)**: Instala o `logiops`, gera `~/.config/logid.cfg` (linkado em `/etc/logid.cfg`, editável sem sudo) mapeando o botão de gesto para troca de workspace/Overview/Mostrar Área de Trabalho e fixando o SmartShift em rolagem livre. Também habilita `kwinrc [Windows] PerOutputVirtualDesktops=true` para a troca de workspace refletir corretamente em setups multi-monitor.
7. **Diagnóstico e Correção de Bateria/Energia**: `diagnose-battery.sh` audita GPU primária do compositor em sistemas híbridos Intel/NVIDIA/AMD (detecta se o KWin compõe numa GPU diferente da que atende o painel interno, mantendo a GPU discreta sempre ligada à toa), política de PCIe ASPM, runtime PM (power/control) de cada dispositivo PCI, saúde da bateria, rádios ociosos (Bluetooth/Docker) e governor de CPU — somente leitura. `configure-battery.sh` aplica só as correções escolhidas pelo usuário (`BATTERY_FIX_GPU_PRIMARY`, `BATTERY_FIX_PCIE_ASPM`, `BATTERY_FIX_PCIE_ASPM_PERSIST`, `BATTERY_FIX_PCI_RUNTIME_PM`, `BATTERY_FIX_PCI_RUNTIME_PM_PERSIST`), sempre criando um snapshot de reversão; `revert-battery.sh` desfaz a última aplicação.
8. **Detecção do bug de colapso do `kxkbrc` (KWin/Plasma)**: `check-status.sh` detecta quando o Plasma regravou `~/.config/kxkbrc` mantendo só o layout que estava ativo no momento do logout, descartando o resto da `LayoutList` (bug conhecido do KWin/Plasma, não causado por esta suite — sintoma típico: o widget de troca de layout some da barra de tarefas após reiniciar). `fix-keyboard.sh` corrige o estado na hora; opcionalmente pode instalar um autostart que reaplica o layout completo a cada login, para o bug não voltar a cada reboot.
9. **Prevenção do bug "Ctrl+`<tecla>` para de funcionar no sistema inteiro" (falha de compilação de keymap do KWin)**: reproduzido e diagnosticado em produção — se `~/.config/kxkbrc`'s `LayoutList` e `VariantList` tiverem números de elementos diferentes no exato momento em que o KWin recarrega o arquivo (disparado por `kwriteconfig6 ... --notify`), o KWin loga `XKB: More/Less layouts than variants: "..." vs. "..."` seguido de `Failed to compile xkb_symbols` / `Could not create xkb keymap from configuration`, e o Ctrl+`<tecla>` (copiar/colar/desfazer/selecionar tudo) para de responder em **todo o sistema** — Qt, GTK e Electron por igual — mesmo digitar texto normal continuando a funcionar. É persistente: sobrevive a re-escritas corretas do `kxkbrc`, a `logout`/login e a trocar de layout; só um **reboot completo** força o KWin a recompilar do zero e recupera. Causa raiz: os scripts desta suite (e o autostart de auto-cura que eles instalam) escreviam `LayoutList` e `VariantList` como chamadas `kwriteconfig6` **separadas**, cada uma com `--notify` — abrindo uma janela onde o KWin via as duas listas com tamanhos diferentes. Corrigido gravando `VariantList`/`DisplayNames` **sem** `--notify` primeiro, e só notificando na **última** escrita (`LayoutList`), quando o arquivo já está inteiramente consistente. Se esse bug voltar a acontecer (por edição manual no System Settings, por exemplo, que pode ter a mesma race condition), a única saída conhecida é reboot completo — não adianta reaplicar config nem só fazer logout.
10. **O fcitx5 quebra `Ctrl+<tecla>` sob Wayland — a suite o desativa**: segundo bug distinto com sintoma idêntico ao item 9, também reproduzido em produção. Rodando como input method nativo do Wayland, o fcitx5 faz *grab* do teclado e engole as combinações com Ctrl (copiar/colar/desfazer/selecionar tudo) em Qt, GTK e Electron por igual, enquanto **letras normais continuam passando** e o mouse (menu de contexto → Colar) continua funcionando — o que torna o sintoma muito confuso. É determinístico: `pkill fcitx5` restaura o Ctrl na hora, reiniciá-lo quebra de novo. Diferencie do item 9 pelo log: no item 9 há `Failed to compile keymap` no journal e só reboot resolve; aqui **não há erro de XKB nenhum** e o KWin reporta o modificador corretamente (confirmado no Debug Console do KWin: `qdbus6 org.kde.KWin /KWin showDebugConsole`, aba *Input Events*, mostra `Modifiers: Control` no evento da tecla) — o evento se perde entre o compositor e o cliente. Como a cedilha não precisa de input method nenhum (item 2), `fix-keyboard.sh` mascara o autostart do fcitx5 e encerra o processo. Se o usuário precisar de um IME de verdade (japonês/chinês/coreano), avise-o desse trade-off antes de reabilitar.
    > **Pegadinha real, também reproduzida em produção**: o pacote `fcitx5` instala seu **próprio** autostart em `/etc/xdg/autostart/org.fcitx.Fcitx5.desktop` — um local separado de `~/.config/autostart/`, e o KDE funde os dois no login. Remover só a cópia do usuário **não basta**: a de sistema reaparece a cada boot e sobe o fcitx5 de novo, mesmo com `~/.config/autostart` limpo. O jeito correto de desativar um autostart de sistema por usuário no XDG é **mascará-lo**: gravar um `.desktop` de mesmo nome em `~/.config/autostart/` com `Hidden=true`, não apenas deixar de instalar uma cópia. `fix-keyboard.sh` e `check-status.sh` fazem isso corretamente desde essa correção; `check-status.sh` também detecta quando a cópia de sistema existe sem máscara e reporta `[FALHA]`, não só quando o fcitx5 está de fato rodando. Como o pacote não serve a nenhum propósito nesta suite, ambos os scripts sugerem (nunca aplicam automaticamente) desinstalá-lo por completo, com o comando certo para pacman/apt/dnf.
12. **Chassis Tongfang / Avell / Clevo — Tecla Control/Fn inoperante sob Linux (Bug de KBC MUX e DSDT ACPI)**: Em laptops com placa Tongfang (Avell A62 LIV, GK5, GM5, Tuxedo Pulse, Schenker), a matriz do teclado ligada ao chip Embedded Controller (EC) ITE IT5570E/IT8528 tem seus bytes na porta I/O `0x60` descartados pelo driver `i8042` quando o kernel usa roteamento PnP padrão ou o caminho ACPI DSDT do Linux. A interrupção elétrica (`IRQ 1`) chega ao processador, mas o `atkbd` não emite eventos no `/dev/input/eventX`. A correção é puramente a nível de kernel via parâmetros de boot no GRUB: `i8042.nopnp=1 i8042.nomux=1 i8042.reset=1 acpi_osi='Windows 2020'`. Além disso, a tecla `Fn` física nesses chassis emite scancode estendido `e078` (código traduzido `0xf8`), que gera avisos de `Unknown key pressed` no journal a menos que seja mapeada no hwdb.
13. **Gerenciamento Dinâmico de Energia do Teclado Integrado (`smart-keyboard-power`)**: Sob o Linux com Runtime PM ativo, a porta `serio0` (i8042) entra em suspensão ociosa (`power/control = auto`), fazendo com que o primeiro pressionamento de modificadores de byte único (`Left Ctrl`) sofra atraso para acordar o barramento. A suite resolve isso de forma inteligente: uma regra udev dinâmica (`/etc/udev/rules.d/90-kde-smart-keyboard-power.rules`) mantém o barramento em `power/control = on` (zero latência, anti-latch) quando o notebook é usado sozinho, e alterna automaticamente para `auto` (economia máxima de bateria) sempre que um teclado externo (USB ou Bluetooth) for conectado.
14. **Chassis Tongfang / Avell — Tecla Control inoperante após fechar/abrir a tampa do laptop (S3 deep sleep resume)**: Ao suspender o laptop fechando a tampa (ACPI S3 deep sleep), o chip Embedded Controller (ITE IT5570E/IT8528) desliga o clock da matriz de varredura. No retorno (abertura da tampa), o kernel Linux acorda sem re-sondar a porta PS/2 (`serio0`), deixando o comparador da linha do `Left Ctrl` em estado descalibrado (*latched*). A suite resolve isso instalando um gancho em `/etc/systemd/system-sleep/90-kde-keyboard-resume.sh` via `./bin/kde-config smart-keyboard-power --apply`, que envia `rescan` para `/sys/devices/platform/i8042/serio0/drvctl` e sincroniza o barramento no milissegundo em que a tampa é aberta.

11. **Registro de execuções e relatório histórico**: até a v1.6.3 a saída de cada comando vivia só no scrollback do terminal — não havia como responder "o que mudou na última execução?" nem "a saúde da bateria está caindo?". Agora **toda execução** grava um run em `~/.local/state/kde-wayland-suite/runs/<timestamp>-<comando>/`, com `events.tsv` (um registro por checagem: `epoch · status · id · detalhe`, com `status` ∈ `ok`/`warn`/`fail`/`skip`/`info`/`metric`), `output.log` (saída bruta sem códigos ANSI) e `meta.env` (comando, código de saída, duração, versão). O comando `report` monta o relatório a partir desses **eventos estruturados**, nunca do texto colorido — que muda a cada ajuste de redação e quebraria qualquer parser. Registros `metric` carregam valores numéricos e viram tendência histórica (ex.: `battery_health_percent` ao longo dos meses). Retenção padrão de 50 runs (`KDE_SUITE_RUNLOG_KEEP`), desligável com `KDE_SUITE_RUNLOG=0`. **Agentes de IA devem ler `events.tsv` em vez de parsear a saída do terminal** para montar as fases Execução e Resumo do formato padronizado.

> **Formato de saída obrigatório**: todo comando desta suite deve ser reportado no formato padronizado definido em `shared/OUTPUT-CONTRACT.md` — três fases (**Plano** → **Execução** → **Resumo**), idêntico em todas as ferramentas (Claude Code, Cursor, OMP, OpenCode e Antigravity). O bloco está replicado ao final de cada `.md` de comando e de skill; ao alterá-lo, atualize a fonte canônica e replique nos demais.

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
| `shared/fix-tongfang.sh` | Desbloqueio de teclado/matriz i8042 em laptops Tongfang/Avell/Clevo via GRUB |
| `shared/test-keyboard.py` | Monitor interativo de eventos de teclas em tempo real (/dev/input/eventX) |
| `shared/monitor-irq.py` | Monitor de pulsos elétricos de hardware no IRQ 1 (teclado i8042) |
| `shared/manage-keyboard-power.sh` | Gerenciamento inteligente de energia do teclado (on sozinho, auto com teclado USB/BT) |
| `shared/preflight-base.sh` | Pré-voo de ambiente, hardware DMI, versão do Plasma e caminho do `qdbus6` |
| `bin/kde-config switch [br\|us]` | Alternância imediata de layout de teclado via D-Bus |

---

## Uso Rápido via CLI

```bash
# Diagnóstico completo
./bin/kde-config status

# Aplicar correção de teclado, cedilha (Chrome/Orca) e clipboard
./bin/kde-config fix-keyboard

# Desbloquear teclado/matriz em laptops Tongfang/Avell/Clevo (GRUB)
./bin/kde-config fix-tongfang

# Monitorar eventos de teclas em tempo real
./bin/kde-config test-keyboard

# Monitorar pulsos elétricos no IRQ 1 (i8042)
./bin/kde-config monitor-irq

# Ativar gerenciamento dinâmico de energia do teclado (anti-latch + economia)
./bin/kde-config smart-keyboard-power --apply

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
