---
description: Inicializa todo o ambiente KDE Plasma 6 Wayland (salva backups, corrige teclado/atalhos, configura gestos de touchpad, configura o mouse Logitech MX Master 3S e instala o CLI).
---

# /init

Executa a inicialização e configuração completa da suíte KDE Wayland com backup automático:

```bash
./bin/kde-config init
```

**Antes de rodar, use `AskUserQuestion` para coletar as escolhas do usuário — nunca rode `init` de forma cega.** Faça as perguntas de uma vez só (uma chamada, todas as perguntas), antes de executar qualquer comando:

1. **Componentes** (multiSelect): Teclado/cedilha/atalhos (Ctrl+C ABNT2) — recomendado; Gestos de touchpad (3/4 dedos) — recomendado se houver touchpad; Mouse Logitech MX Master 3S (logiops) — só se o usuário tiver o mouse; Diagnóstico de bateria/energia — recomendado (é só diagnóstico nesta pergunta, sem aplicar nada ainda).
2. **Auto-cura do layout no login**: proteger contra o bug do KWin/Plasma que pode colapsar `~/.config/kxkbrc` para um único layout ao reiniciar (o widget de troca de layout some da barra) — recomendado, mas adiciona uma entrada de autostart.

Depois, rode `init` com as variáveis correspondentes às respostas:

```bash
# Componente não escolhido -> pule com SKIP_*; auto-cura aceita -> KDE_SUITE_LAYOUT_AUTOHEAL=1
SKIP_GESTURES=1 SKIP_MOUSE=1 KDE_SUITE_LAYOUT_AUTOHEAL=1 ./bin/kde-config init
```

`SKIP_KEYBOARD`, `SKIP_GESTURES`, `SKIP_MOUSE` e `SKIP_BATTERY` pulam cada etapa quando o usuário não quiser aquele componente. Se o usuário pedir para configurar só uma coisa específica, pule este fluxo de perguntas e rode o comando específico direto (`./bin/kde-config mouse`, etc.).

### Bateria: diagnóstico dentro do `init`, correção fora dele

Se o componente "Diagnóstico de bateria/energia" for escolhido, o `init` só roda `battery-status` (leitura, seguro, sempre pode rodar). **Não** passe `BATTERY_FIX_*` durante o fluxo de `init` — a decisão de aplicar cada correção de bateria é um segundo momento, depois de ver o diagnóstico real da máquina. Depois que o `init` terminar e você ver os achados na saída, siga o fluxo do `/battery` (`commands/battery.md`): explique cada achado, pergunte via `AskUserQuestion` o que aplicar, e só então rode `./bin/kde-config battery-apply` com as variáveis correspondentes.
