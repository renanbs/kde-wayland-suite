---
name: kde-wayland-suite
description: Comprehensive KDE Plasma 6 Wayland configuration suite for keyboard shortcuts (Ctrl+C ABNT2 fix), cedilla on US-intl (Chrome, Orca IDE, Electron, GTK, Qt via LC_CTYPE, XCompose & Wayland IME flags), and 3/4-finger touchpad gestures using libinput-gestures and KWin D-Bus.
---

# KDE Plasma 6 Wayland Suite (Claude Code Plugin)

Esta skill permite ao Claude Code auditar e corrigir problemas de teclado, atalhos, cedilha no layout US-intl (Chrome, Orca, Electron) e gestos de touchpad no KDE Plasma 6 Wayland. Todos os recursos executáveis residem no próprio diretório da skill.

## Comandos

- Auditoria: `bin/kde-config status`
- Correção de Teclado & Cedilha: `bin/kde-config fix-keyboard`
- Gestos: `bin/kde-config gestures`
- Mouse (Logitech MX Master 3S): `bin/kde-config mouse`
- Alternância de Layout: `bin/kde-config switch [br|us]`
