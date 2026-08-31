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
- **Alternar Layouts**: `bin/kde-config switch [br|us]`
- **Diagnóstico Pré-Voo**: `bin/kde-config preflight` (ou `shared/preflight-base.sh`)
- **Restaurar Backup**: `bin/kde-config rollback`
