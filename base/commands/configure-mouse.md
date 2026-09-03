---
description: Instala o logiops e configura o Logitech MX Master 3S no KDE Plasma 6 Wayland — botão de gesto para troca de workspace/overview e SmartShift fixo em rolagem livre.
---

# /configure-mouse

Instala o `logiops` (se necessário), gera `~/.config/logid.cfg`, linka em `/etc/logid.cfg` e ativa o serviço `logid.service` para o Logitech MX Master 3S.

```bash
./bin/kde-config mouse
```

## O que é configurado

- **Botão de gesto** (grande, sob o polegar): segurar+arrastar troca de workspace (`Meta+Ctrl+Left/Right`, sem mover a janela ativa junto), cima/toque = Overview (`Meta+W`), baixo = Mostrar Área de Trabalho (`Meta+D`).
- **Multi-monitor**: habilita `Switch desktops independently for each screen` no KWin, garantindo que a troca de workspace pelo botão de gesto reflita corretamente em setups com múltiplos monitores.
- **Roda de rolagem**: SmartShift desligado, fixa no modo livre (sem "travinhas"). Pressione o botão físico embaixo da roda uma vez após aplicar a config para fixar o modo livre.
- Config editável sem sudo em `~/.config/logid.cfg` — depois de editar, rode `sudo systemctl restart logid.service` para recarregar.
