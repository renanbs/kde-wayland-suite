---
name: kde-wayland-suite
description: Comprehensive KDE Plasma 6 Wayland configuration suite for keyboard shortcuts (Ctrl+C ABNT2 fix), XCompose cedilla on US-intl, Wayland clipboard repair (wl-clipboard/xsel deadlock fix), and 3/4-finger touchpad gestures using libinput-gestures and KWin D-Bus.
---

# KDE Plasma 6 Wayland Suite

Esta skill gerencia configurações, diagnósticos e correções de teclado, atalhos, área de transferência (clipboard) e gestos de touchpad no **KDE Plasma 6 (Wayland)**.

## Diagnóstico e Ações

- **Auditoria de Saúde**: Executar `bash shared/check-status.sh` ou `./bin/kde-config status`.
- **Correção de Teclado, Atalhos e Clipboard**: Executar `bash shared/fix-keyboard.sh` ou `./bin/kde-config fix-keyboard`.
- **Configuração de Gestos**: Executar `bash shared/configure-gestures.sh` ou `./bin/kde-config gestures`.
- **Alternar Layouts**: Executar `./bin/kde-config switch [br|us]`.
