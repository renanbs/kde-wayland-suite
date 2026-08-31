---
name: configure-mouse
description: Instala o logiops e configura o Logitech MX Master 3S no KDE Plasma 6 Wayland — botão de gesto para troca de workspace/overview e SmartShift fixo em rolagem livre.
---

# Configuração do Mouse (Logitech MX Master 3S) — KDE Wayland

Execute a configuração do mouse:

```bash
./bin/kde-config mouse
```

Configura:
- Botão de gesto (sob o polegar): arrastar troca de workspace, cima/toque = Overview, baixo = Mostrar Área de Trabalho.
- Multi-monitor: habilita `Switch desktops independently for each screen` no KWin.
- SmartShift desligado, roda de rolagem sempre no modo livre.
- Config em `~/.config/logid.cfg`, linkada em `/etc/logid.cfg`, editável sem sudo.
