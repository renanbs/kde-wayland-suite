---
description: Inicializa e salva todo o ambiente KDE Plasma 6 Wayland com backups automáticos.
---

# Init (Cursor)

```bash
./bin/kde-config init
```

**Antes de rodar, use `AskUserQuestion` para coletar as escolhas do usuário — nunca rode `init` de forma cega.** Faça as perguntas de uma vez só (uma chamada, todas as perguntas), antes de executar qualquer comando:

1. **Componentes** (multiSelect): Teclado/cedilha/atalhos (Ctrl+C ABNT2) — recomendado; Gestos de touchpad (3/4 dedos) — recomendado se houver touchpad; Mouse Logitech MX Master 3S (logiops) — só se o usuário tiver o mouse.
2. **Auto-cura do layout no login**: proteger contra o bug do KWin/Plasma que pode colapsar `~/.config/kxkbrc` para um único layout ao reiniciar (o widget de troca de layout some da barra) — recomendado, mas adiciona uma entrada de autostart.

Depois, rode `init` com as variáveis correspondentes às respostas:

```bash
# Componente não escolhido -> pule com SKIP_*; auto-cura aceita -> KDE_SUITE_LAYOUT_AUTOHEAL=1
SKIP_GESTURES=1 SKIP_MOUSE=1 KDE_SUITE_LAYOUT_AUTOHEAL=1 ./bin/kde-config init
```

`SKIP_KEYBOARD`, `SKIP_GESTURES` e `SKIP_MOUSE` pulam cada etapa quando o usuário não quiser aquele componente. Se o usuário pedir para configurar só uma coisa específica, pule este fluxo de perguntas e rode o comando específico direto (`./bin/kde-config mouse`, etc.).
