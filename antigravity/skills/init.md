---
name: init
description: Inicializa e salva todas as configurações de teclado, atalhos, XCompose, gestos e mouse Logitech MX Master 3S no KDE Plasma 6 Wayland com backup automático.
---

# Inicialização Geral — KDE Wayland

Execute a inicialização completa:

```bash
./bin/kde-config init
```

**Antes de rodar, use `AskUserQuestion` para coletar as escolhas do usuário — nunca rode `init` de forma cega.** Faça as perguntas de uma vez só (uma chamada, todas as perguntas), antes de executar qualquer comando:

1. **Componentes** (multiSelect): Teclado/cedilha/atalhos (Ctrl+C ABNT2) — recomendado; Gestos de touchpad (3/4 dedos) — recomendado se houver touchpad; Mouse Logitech MX Master 3S (logiops) — só se o usuário tiver o mouse; Diagnóstico de bateria/energia — recomendado (só diagnóstico nesta etapa, sem aplicar nada ainda).
2. **Auto-cura do layout no login**: proteger contra o bug do KWin/Plasma que pode colapsar `~/.config/kxkbrc` para um único layout ao reiniciar (o widget de troca de layout some da barra) — recomendado, mas adiciona uma entrada de autostart.

Depois, rode `init` com as variáveis correspondentes às respostas:

```bash
# Componente não escolhido -> pule com SKIP_*; auto-cura aceita -> KDE_SUITE_LAYOUT_AUTOHEAL=1
SKIP_GESTURES=1 SKIP_MOUSE=1 KDE_SUITE_LAYOUT_AUTOHEAL=1 ./bin/kde-config init
```

`SKIP_KEYBOARD`, `SKIP_GESTURES`, `SKIP_MOUSE` e `SKIP_BATTERY` pulam cada etapa quando o usuário não quiser aquele componente. Se o usuário pedir para configurar só uma coisa específica, pule este fluxo de perguntas e rode o comando específico direto (`./bin/kde-config mouse`, etc.).

### Bateria: diagnóstico dentro do `init`, correção fora dele

`init` só roda o diagnóstico de bateria (`battery-status`, leitura). **Não passe `BATTERY_FIX_*` durante o `init`.** Depois de ver os achados, siga o skill `battery` (`skills/battery.md`): explique cada achado, pergunte via `AskUserQuestion` o que aplicar, e só então rode `./bin/kde-config battery-apply`.

---

## Formato de saída (obrigatório e idêntico em todas as ferramentas)

Reporte sempre nestas três fases, nesta ordem, com estes títulos exatos.

**1. Plano** — antes de executar qualquer coisa:

- **Comando:** a linha exata que será executada
- **Faz:** uma frase sobre o que muda no sistema
- **Reversível:** como desfazer — ou `não aplicável` quando for só leitura

**2. Execução** — uma linha por etapa, com o marcador do resultado:

- `✅ <etapa>` — concluída e verificada
- `⏭️ <etapa>` — pulada (diga por quê)
- `⚠️ <etapa>` — concluída com ressalva (diga qual)
- `❌ <etapa>` — falhou (cole a mensagem de erro real, não parafraseie)

**3. Resumo** — sempre ao final, mesmo quando nada mudou:

| Campo | Conteúdo |
| :--- | :--- |
| O que mudou | lista objetiva, ou `nada — já estava correto` |
| O que não mudou | o que foi pulado ou recusado, e por quê |
| Backup | caminho do snapshot, ou `nenhum` |
| Como reverter | o comando exato |
| Requer | `nada` \| `logout/login` \| `reboot` |

**Regras:**

- Nunca declare sucesso sem verificar: rode o `status` correspondente ou releia o arquivo alterado antes de marcar `✅`.
- Se algo precisar de `sudo` e a sessão não tiver TTY, não tente contornar — peça ao usuário para rodar com o prefixo `!` e mostre a linha exata.
- Falhas entram no relatório com a saída real do comando; nunca omita nem suavize um erro.
- Se uma correção exigir logout ou reboot para valer, diga isso no `Requer` e repita no texto.
