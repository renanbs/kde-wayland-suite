---
name: kde-wayland-suite
description: Comprehensive KDE Plasma 6 Wayland configuration suite for keyboard shortcuts (Ctrl+C ABNT2 fix), cedilla on US-intl (Chrome, Orca IDE, Electron, GTK, Qt via LC_CTYPE, XCompose & Wayland IME flags), Wayland clipboard repair (wl-clipboard/xsel deadlock fix), and 3/4-finger touchpad gestures using libinput-gestures and KWin D-Bus.
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

---

## Comandos Disponíveis

| Comando | Descrição |
| :--- | :--- |
| `shared/check-status.sh` | Auditoria completa de ambiente, teclado, cedilha (Chrome/Orca), clipboard Wayland, variáveis IM e gestos |
| `shared/fix-keyboard.sh` | Correção de `Ctrl+C`, cedilha no US-intl (Chrome, Orca, Electron), deadlock de clipboard e recarregamento via KWin |
| `shared/configure-gestures.sh` | Setup de `libinput-gestures.conf` e reinício de serviço |
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

# Alternar layout ativo
./bin/kde-config switch br
./bin/kde-config switch us
```
