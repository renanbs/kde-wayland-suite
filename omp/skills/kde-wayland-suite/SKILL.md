---
name: kde-wayland-suite
description: Comprehensive KDE Plasma 6 Wayland configuration suite for keyboard shortcuts (Ctrl+C ABNT2 fix), cedilla on US-intl (Chrome, Orca IDE, Electron, GTK, Qt via LC_CTYPE, XCompose & Wayland IME flags), and 3/4-finger touchpad gestures using libinput-gestures and KWin D-Bus.
---

# KDE Plasma 6 Wayland Suite (OMP Plugin)

Esta skill fornece automações e diagnósticos autocontidos para o ambiente **KDE Plasma 6 (Wayland)**. Todos os recursos executáveis (`bin/kde-config` e `shared/`) residem no próprio diretório da skill.

## Comandos Disponíveis

Ao invocar esta skill no OMP, execute o binário empacotado `bin/kde-config` (ou os scripts em `shared/`):

- **Auditoria de Saúde**: `bin/kde-config status` (ou `shared/check-status.sh`)
- **Correção de Teclado, Cedilha (Chrome/Orca) & Atalhos**: `bin/kde-config fix-keyboard` (ou `shared/fix-keyboard.sh`)
- **Gestos de Touchpad**: `bin/kde-config gestures` (ou `shared/configure-gestures.sh`)
- **Mouse Logitech MX Master 3S**: `bin/kde-config mouse` (ou `shared/configure-mouse.sh`)
- **Alternar Layouts**: `bin/kde-config switch [br|us]`
- **Diagnóstico Pré-Voo**: `bin/kde-config preflight` (ou `shared/preflight-base.sh`)
- **Restaurar Backup**: `bin/kde-config rollback`

## Bug conhecido: colapso do `kxkbrc` (KWin/Plasma)

`check-status.sh` detecta quando o Plasma regravou `~/.config/kxkbrc` mantendo só o layout ativo no momento do logout, descartando o resto da `LayoutList` (bug do KWin/Plasma, não causado por esta suite — sintoma: o widget de troca de layout some da barra após reiniciar). `fix-keyboard.sh` corrige o estado na hora; opcionalmente instala um autostart que reaplica o layout completo a cada login.

> **Importante para agentes de IA**: a auto-cura no login (`KDE_SUITE_LAYOUT_AUTOHEAL=1`) **não deve ser habilitada automaticamente** — pergunte ao usuário antes, pois adiciona uma entrada de autostart à sessão dele. Sem a variável, `fix-keyboard` continua corrigindo o `kxkbrc` normalmente, só não instala o autostart.

## Fluxo Guiado de `init` (obrigatório para agentes de IA)

`init` configura várias coisas de uma vez (teclado, gestos, mouse, atalhos). **Nunca rode `init` de forma cega.** Antes de executar qualquer comando, use a ferramenta `AskUserQuestion` para coletar todas as escolhas do usuário de uma vez só (uma única chamada, múltiplas perguntas), e só então rode `./bin/kde-config init` com as variáveis de ambiente correspondentes. Não pergunte no meio da execução — colete tudo antes.

Pergunta 1 — **Componentes** (multiSelect): "Teclado, cedilha e atalhos (Ctrl+C ABNT2)" (recomendado); "Gestos de touchpad (3/4 dedos)" (recomendado se houver touchpad); "Mouse Logitech MX Master 3S (logiops)" (só se o usuário tiver o mouse).

Pergunta 2 — **Auto-cura do layout no login** (single-select): "Sim, proteger contra o bug do KWin/Plasma (recomendado)" vs. "Não, prefiro corrigir manualmente se acontecer".

```bash
# Exemplo: sem mouse, com auto-cura
SKIP_MOUSE=1 KDE_SUITE_LAYOUT_AUTOHEAL=1 ./bin/kde-config init
```

`SKIP_KEYBOARD`, `SKIP_GESTURES` e `SKIP_MOUSE` pulam cada etapa. Se o usuário pedir para configurar só uma coisa específica, pule este fluxo e rode o comando direto (`./bin/kde-config mouse`, etc.).

