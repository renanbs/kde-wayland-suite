---
description: Corrige o problema de atalhos (Ctrl+C) no layout ABNT2, remove variáveis legadas de IM e configura o suporte completo a cedilha no US-intl para Chrome, Orca IDE, Electron, GTK e Qt no KDE Wayland.
---

# fix-keyboard

Aplica a correção atômica para teclado, atalhos e cedilha (' + c -> ç) no KDE Plasma 6 Wayland.

```bash
./bin/kde-config fix-keyboard
```

Antes de rodar, pergunte ao usuário se ele quer habilitar a **auto-cura do layout no login**: o Plasma tem um bug conhecido que, ao encerrar a sessão, pode regravar `~/.config/kxkbrc` mantendo só o layout ativo no momento do logout (o `br` some, o widget de troca de layout desaparece da barra). Se ele quiser proteção automática contra isso em todo reboot, rode com a variável habilitada:

```bash
KDE_SUITE_LAYOUT_AUTOHEAL=1 ./bin/kde-config fix-keyboard
```

Isso instala uma entrada de autostart que reaplica o layout completo (`br,us`) a cada login. Se o usuário não quiser essa entrada extra de autostart, rode sem a variável — o comando corrige o `kxkbrc` na hora normalmente.
