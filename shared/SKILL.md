---
name: kde-wayland-suite
description: Comprehensive KDE Plasma 6 Wayland configuration suite for keyboard shortcuts (Ctrl+C ABNT2 fix), XCompose cedilla on US-intl, and 3/4-finger touchpad gestures using libinput-gestures and KWin D-Bus.
---

# KDE Plasma 6 Wayland Suite (Keyboard, Shortcuts & Gestures)

Esta skill fornece automações e diagnósticos para resolver problemas comuns no **KDE Plasma 6 (Wayland)**:

1. **Correção de Atalhos de Teclado (`Ctrl+C` no ABNT2)**: Elimina o módulo legado `im-cedilla` que sequestra eventos de teclas e quebra o `Ctrl+C` sob Wayland.
2. **Suporte a Cedilha no US-intl (`' + c` $\to$ `ç`)**: Configura `~/.XCompose` nativo sem necessidade de variáveis `GTK_IM_MODULE` / `QT_IM_MODULE`.
3. **Gestos de Touchpad Portáveis**: Mapeia gestos de 3 e 4 dedos complementares ao KWin via `libinput-gestures` e D-Bus (`qdbus6`), sem conflitos de concorrência com gestos nativos do Plasma.
4. **Diagnóstico e Verificação Geral**: Executa auditoria em tempo real da sessão, layouts ativos, permissões e estado dos daemons.

---

## Comandos Disponíveis

| Comando | Descrição |
| :--- | :--- |
| `shared/check-status.sh` | Auditoria completa de ambiente, teclado, variáveis IM e gestos |
| `shared/fix-keyboard.sh` | Correção de `Ctrl+C`, remoção de `im.conf`, criação de `~/.XCompose` e recarregamento via KWin |
| `shared/configure-gestures.sh` | Setup de `libinput-gestures.conf` e reinício de serviço |
| `shared/preflight-base.sh` | Pré-voo de ambiente, versão do Plasma e caminho do `qdbus6` |
| `bin/kde-config switch [br\|us]` | Alternância imediata de layout de teclado via D-Bus |

---

## Uso Rápido via CLI

```bash
# Diagnóstico completo
./bin/kde-config status

# Aplicar correção de teclado
./bin/kde-config fix-keyboard

# Aplicar configuração de gestos
./bin/kde-config gestures

# Alternar layout ativo
./bin/kde-config switch br
./bin/kde-config switch us
```
